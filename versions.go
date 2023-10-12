package main

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
)

type Versions struct {
	toolVersions map[string]string
}

// https://www.ruby-lang.org/en/downloads/releases/ || asdf list all ruby
func (v *Versions) Ruby() string {
	return v.toolVersions["ruby"]
}

// https://hub.docker.com/r/flyio/flyctl/tags
func (v *Versions) Flyctl() string {
	return v.toolVersions["flyctl"]
}

// https://github.com/aptible/supercronic/releases
func (v *Versions) Supercronic() string {
	return "0.2.26"
}

// https://app-updates.agilebits.com/product_history/CLI2
func (v *Versions) _1Password() string {
	return "2.21.0"
}

// https://hub.docker.com/_/alpine/tags
func (v *Versions) Alpine() string {
	return "3.18.4@sha256:48d9183eb12a05c99bcc0bf44a003607b8e941e1d4f41f9ad12bdcc4b5672f86"
}

func currentToolVersions() *Versions {
	return &Versions{
		toolVersions: toolVersions(),
	}
}

func toolVersions() map[string]string {
	wd, err := os.Getwd()
	if err != nil {
		panic(err)
	}
	versions, err := os.Open(filepath.Join(wd, ".tool-versions"))
	if err != nil {
		panic(err)
	}
	toolVersions := make(map[string]string)
	scanner := bufio.NewScanner(versions)
	for scanner.Scan() {
		line := scanner.Text()
		toolAndVersion := strings.Split(line, " ")
		toolVersions[toolAndVersion[0]] = toolAndVersion[1]
	}

	return toolVersions
}
