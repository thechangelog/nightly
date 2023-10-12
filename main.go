package main

import (
	"context"
	"log"
	"os"
	"time"

	"dagger.io/dagger"
	"github.com/urfave/cli/v2"
)

func main() {
	ctx := context.Background()
	dag, err := dagger.Connect(ctx, dagger.WithLogOutput(os.Stderr))
	if err != nil {
		panic(err)
	}
	defer dag.Close()

	app := &cli.App{
		Name:     "nightly",
		Usage:    "Changelog Nightly CI/CD pipeline commands",
		Version:  "v2023.10.10",
		Compiled: time.Now(),
		Authors: []*cli.Author{
			{
				Name:  "Jerod Santo",
				Email: "jerod@changelog.com",
			},
			{
				Name:  "Gerhard Lazu",
				Email: "gerhard@changelog.com",
			},
		},
		Flags: []cli.Flag{
			&cli.BoolFlag{
				Name:    "nocache",
				Aliases: []string{"n"},
				Usage:   "Bust Dagger ops cache",
				EnvVars: []string{"NOCACHE"},
			},
			&cli.BoolFlag{
				Name:    "debug",
				Aliases: []string{"d"},
				Usage:   "Debug command",
				EnvVars: []string{"DEBUG"},
			},
			&cli.StringFlag{
				Name:    "platform",
				Aliases: []string{"p"},
				Usage:   "Runtime platform",
				Value:   "linux/amd64",
				EnvVars: []string{"PLATFORM"},
			},
		},
		Commands: []*cli.Command{
			{
				Name:    "build",
				Aliases: []string{"b"},
				Usage:   "Builds container image",
				Action: func(cCtx *cli.Context) error {
					newPipeline(ctx, cCtx, dag).
						Build()

					return nil
				},
			},
			{
				Name:    "test",
				Aliases: []string{"t"},
				Usage:   "Runs tests",
				Action: func(cCtx *cli.Context) error {
					newPipeline(ctx, cCtx, dag).
						Build().
						Test()

					return nil
				},
			},
			{
				Name:  "cicd",
				Usage: "Runs the entire CI/CD pipeline",
				Flags: []cli.Flag{
					&cli.StringFlag{
						Name:     "app",
						Aliases:  []string{"a"},
						Usage:    "Fly.io app name",
						EnvVars:  []string{"APP"},
						Required: true,
					},
				},
				Action: func(cCtx *cli.Context) error {
					newPipeline(ctx, cCtx, dag).
						Build().
						Test().
						Prod().
						Deploy()

					return nil
				},
			},
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}
