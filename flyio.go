package main

import (
	"fmt"
	"os"
	"strings"
	"time"

	"dagger.io/dagger"
)

type Flyio struct {
	app               string
	deployWait        string
	publishedImageRef string
	org               string
	pipeline          *Pipeline
	region            string
	registry          string
	token             *dagger.Secret
	version           string
	volume            string
	volumeSize        string
}

func newFlyio(p *Pipeline) *Flyio {
	token := os.Getenv("FLY_API_TOKEN")
	if token == "" {
		panic("FLY_API_TOKEN env var must be set")
	}

	f := &Flyio{
		app:        p.app,
		deployWait: "180",
		org:        "changelog",
		pipeline:   p,
		region:     "ord",
		registry:   "registry.fly.io",
		token:      p.dag.SetSecret("FLY_API_TOKEN", token),
		version:    p.tools.Flyctl(),
		volumeSize: "2",
	}

	f.volume = strings.ReplaceAll(f.app, "-", "_")

	return f
}

func (f *Flyio) Cli() *dagger.Container {
	flyctl := f.pipeline.Container().Pipeline("flyctl").
		From(fmt.Sprintf("flyio/flyctl:v%s", f.version)).
		File("/flyctl")

	// we need Alpine so that we can run shell scripts that set secrets in secure way
	container := f.pipeline.Container().Pipeline("fly.io").
		From(fmt.Sprintf("alpine:%s", f.pipeline.tools.Alpine())).
		WithFile("/usr/local/bin/flyctl", flyctl, dagger.ContainerWithFileOpts{Permissions: 755}).
		WithExec([]string{"flyctl", "version"}).
		WithSecretVariable("FLY_API_TOKEN", f.token).
		WithEnvVariable("RUN_AT", time.Now().String()).
		WithNewFile("fly.toml", dagger.ContainerWithNewFileOpts{
			Contents: f.Config(),
		})

	_, err := container.File("fly.toml").Export(f.pipeline.ctx, "fly.toml")
	if err != nil {
		panic(err)
	}

	return container
}

func (f *Flyio) Config() string {
	return fmt.Sprintf(`# https://fly.io/docs/reference/configuration/
app = "%s"
primary_region = "%s"

[env]
		# used by supercronic - https://changelog-media.sentry.io/settings/projects/changelog-com/keys/
		SENTRY_DSN = "https://2b1aed8f16f5404cb2bc79b855f2f92d@o546963.ingest.sentry.io/5668962"
		DB_DIR = "/app/dist"

[mounts]
	source = "%s"
	destination = "/app/dist"

[http_service]
	internal_port = 80
	force_https = true

[[http_service.checks]]
	method = "GET"
	path = "/health"
	interval = "5s"
	timeout = "4s"`, f.app, f.region, f.volume)
}

func (f *Flyio) App() *Flyio {
	cli := f.Cli()

	_, err := cli.
		WithExec([]string{"flyctl", "status"}).
		Sync(f.pipeline.ctx)
	if err != nil {
		_, err = cli.
			WithExec([]string{"flyctl", "apps", "create", f.app, "--org", f.org}).
			WithExec([]string{"flyctl", "volume", "create", f.volume, "--yes", "--region", f.region, "--size", f.volumeSize}).
			Sync(f.pipeline.ctx)
		if err != nil {
			panic(err)
		}
	}

	return f
}

func (f *Flyio) ImageRef() string {
	gitSHA := os.Getenv("GITHUB_SHA")
	if gitSHA == "" {
		gitSHA = "dev"
	}

	return fmt.Sprintf("%s/%s:%s", f.registry, f.app, gitSHA)
}

func (f *Flyio) Publish() *Flyio {
	var err error

	f.publishedImageRef, err = f.pipeline.workspace.
		Pipeline("publish").
		WithRegistryAuth(f.registry, "x", f.token).
		Publish(f.pipeline.ctx, f.ImageRef())
	if err != nil {
		panic(err)
	}

	return f
}

func (f *Flyio) Secrets(secrets map[string]string) *Flyio {
	cli := f.Cli().Pipeline("secrets")
	var envs []string
	for name, secret := range secrets {
		cli = cli.WithSecretVariable(name, f.pipeline.dag.SetSecret(name, secret))
		envs = append(envs, fmt.Sprintf(`%s="$%s"`, name, name))
	}

	_, err := cli.WithNewFile("/flyctl-set-secrets-and-keep-hidden.sh", dagger.ContainerWithNewFileOpts{
		Contents: fmt.Sprintf(`#!/bin/sh
flyctl secrets set %s --app %s --stage`, strings.Join(envs, " "), f.app),
		Permissions: 755,
	}).
		WithExec([]string{"/flyctl-set-secrets-and-keep-hidden.sh"}).
		Sync(f.pipeline.ctx)
	if err != nil {
		panic(err)
	}

	return f
}

func (f *Flyio) Deploy() *Flyio {
	_, err := f.Cli().Pipeline("deploy").
		WithExec([]string{
			"flyctl", "deploy", "--now",
			"--app", f.app,
			"--image", f.publishedImageRef,
			"--wait-timeout", f.deployWait,
		}).
		Sync(f.pipeline.ctx)
	if err != nil {
		panic(err)
	}

	return f
}
