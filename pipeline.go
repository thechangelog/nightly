package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"dagger.io/dagger"
	"github.com/urfave/cli/v2"
)

type Pipeline struct {
	app       string
	ctx       context.Context
	dag       *dagger.Client
	debug     bool
	nocache   bool
	platform  dagger.Platform
	workspace *dagger.Container
	tools     *Versions
}

func newPipeline(ctx context.Context, cCtx *cli.Context, dag *dagger.Client) *Pipeline {
	p := &Pipeline{
		app:      cCtx.String("app"),
		ctx:      ctx,
		platform: dagger.Platform(cCtx.String("platform")),
		debug:    cCtx.Bool("debug"),
		nocache:  cCtx.Bool("nocache"),
		dag:      dag,
		tools:    currentToolVersions(),
	}

	p.workspace = p.Container()

	return p
}

func (p *Pipeline) OK() *Pipeline {
	var err error
	p.workspace, err = p.workspace.Sync(p.ctx)
	if err != nil {
		panic(err)
	}
	return p
}

func (p *Pipeline) platformKebab() string {
	return strings.ReplaceAll(string(p.platform), "/", "-")
}

func (p *Pipeline) platformSnake() string {
	return strings.ReplaceAll(string(p.platform), "/", "_")
}

func (p *Pipeline) Container() *dagger.Container {
	return p.dag.Container(dagger.ContainerOpts{
		Platform: p.platform,
	})
}

func (p *Pipeline) Build() *Pipeline {
	p.workspace = p.workspace.Pipeline("container image").
		From(fmt.Sprintf("ruby:%s-alpine", p.tools.Ruby())).
		WithExec([]string{"ruby", "--version"}).
		WithExec([]string{"apk", "update"}).
		WithExec([]string{"apk", "add", "git", "build-base", "sqlite-dev", "bash"})

	if p.nocache {
		p.workspace = p.workspace.WithEnvVariable("DAGGER_CACHE_BUSTED_AT", time.Now().String())
	}

	app := p.dag.Host().Directory(".", dagger.HostDirectoryOpts{
		Include: []string{
			"images",
			"lib",
			"styles",
			"views",
			"Gemfile",
			"Gemfile.lock",
			"LICENSE",
			"Procfile",
			"Rakefile",
			"env.op",
		}})

	pathWithBundleBin := "/usr/local/bundle/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

	p.workspace = p.workspace.
		WithDirectory("/app", app).
		WithWorkdir("/app").
		WithExec([]string{"bundle", "install", "--frozen", "--without=test"}).
		WithEnvVariable("PATH", pathWithBundleBin).
		WithNewFile("/etc/profile.d/append-bundle-bin-to-path.sh", dagger.ContainerWithNewFileOpts{
			Contents: fmt.Sprintf("export PATH=%s", pathWithBundleBin),
		}).
		WithExec([]string{"rake", "-T"}).
		WithExec([]string{"foreman", "check"}).
		WithEntrypoint(nil).
		WithDefaultArgs()

	p.workspace = p.workspace.
		WithExec([]string{"apk", "add", "nginx"}).
		WithFile("/etc/nginx/nginx.conf", p.dag.Host().File("nginx.conf")).
		WithExec([]string{"nginx", "-t"})

	p.workspace = p.workspace.
		WithFile("/usr/local/bin/supercronic",
			p.supercronic(), dagger.ContainerWithFileOpts{Permissions: 555}).
		WithFile("/app/crontab",
			p.dag.Host().File("crontab")).
		WithExec([]string{"supercronic", "-test", "crontab"})

	p.workspace = p.workspace.
		WithFile("/usr/local/bin/op",
			p.op(), dagger.ContainerWithFileOpts{Permissions: 555}).
		WithExec([]string{"op", "--version"})

	if p.debug {
		token := os.Getenv("OP_SERVICE_ACCOUNT_TOKEN")
		if token == "" {
			panic("OP_SERVICE_ACCOUNT_TOKEN env var must be set")
		}

		p.workspace = p.workspace.Pipeline("generate with local config").
			WithSecretVariable("OP_SERVICE_ACCOUNT_TOKEN", p.dag.SetSecret("OP_SERVICE_ACCOUNT_TOKEN", token)).
			WithExec([]string{"op", "inject", "--in-file", "env.op", "--out-file", ".env"}).
			WithExec([]string{"op", "read", "--out-file", "bq-key.p12", "op://nightly/app/bq-key.p12"}).
			WithExec([]string{"op", "read", "--out-file", "github.db", "--force", "op://nightly/app/github.db"}).
			WithExec([]string{"apk", "add", "tmux", "vim", "htop", "strace"}).
			WithExec([]string{"bash", "-c", `DATE=2023-10-10 rake generate`}).
			WithEntrypoint([]string{"tmux"})

		_, err := p.workspace.Pipeline("export tmp/image.tar").
			Export(p.ctx, "tmp/image.tar")
		if err != nil {
			panic(err)
		}
	}

	return p.OK()
}

func (p *Pipeline) Test() *Pipeline {
	if p.nocache {
		p.workspace = p.workspace.WithEnvVariable("DAGGER_CACHE_BUSTED_AT", time.Now().String())
	}

	p.workspace = p.workspace.
		WithExec([]string{"bundle", "install", "--frozen", "--with=test"}).
		WithDirectory("/app/spec", p.dag.Host().Directory("spec")).
		WithExec([]string{"rspec"})

	return p.OK()
}

func (p *Pipeline) Prod() *Pipeline {
	if p.nocache {
		p.workspace = p.workspace.WithEnvVariable("DAGGER_CACHE_BUSTED_AT", time.Now().String())
	}

	p.workspace = p.workspace.WithNewFile("/entrypoint.sh", dagger.ContainerWithNewFileOpts{
		Contents: `#!/bin/bash
set -ex
op inject --in-file env.op --out-file .env
op read --out-file bq-key.p12 --force op://nightly/app/bq-key.p12
foreman start`,
		Permissions: 555,
	}).
		WithEntrypoint([]string{"/entrypoint.sh"})

	return p.OK()
}

func (p *Pipeline) Deploy() *Pipeline {
	token := os.Getenv("OP_SERVICE_ACCOUNT_TOKEN")
	if token == "" {
		panic("OP_SERVICE_ACCOUNT_TOKEN env var must be set")
	}

	secretEnvs := map[string]string{
		"OP_SERVICE_ACCOUNT_TOKEN": token,
	}

	newFlyio(p).
		App().
		Publish().
		Secrets(secretEnvs).
		Deploy()

	return p
}

func (p *Pipeline) op() *dagger.File {
	file := fmt.Sprintf("op_%s_v%s.zip", p.platformSnake(), p.tools._1Password())
	url := fmt.Sprintf("https://cache.agilebits.com/dist/1P/op2/pkg/v%s/%s", p.tools._1Password(), file)

	// https://hub.docker.com/layers/library/alpine/3.18.4/images/sha256-48d9183eb12a05c99bcc0bf44a003607b8e941e1d4f41f9ad12bdcc4b5672f86
	return p.Container().From("alpine@sha256:48d9183eb12a05c99bcc0bf44a003607b8e941e1d4f41f9ad12bdcc4b5672f86").
		WithFile(file, p.dag.HTTP(url)).
		WithExec([]string{"unzip", file}).
		WithExec([]string{"mv", "op", "/usr/local/bin/op"}).
		WithExec([]string{"op", "--version"}).
		File("/usr/local/bin/op")
}

func (p *Pipeline) supercronic() *dagger.File {
	return p.dag.HTTP(
		fmt.Sprintf(
			"https://github.com/aptible/supercronic/releases/download/v%s/supercronic-%s",
			p.tools.Supercronic(),
			p.platformKebab(),
		),
	)
}
