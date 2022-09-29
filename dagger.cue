package main

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/aws"
	"universe.dagger.io/docker"
)

#ImageBuild: {
	app: dagger.#FS

	_pull: docker.#Pull & {
		source: "ruby:3.1.2-alpine"
	}

	_copy: docker.#Copy & {
		input: _pull.output
		contents: app
		dest: "/app"
	}

	_run: docker.#Run & {
		input: _copy.output
	}

	_set: docker.#Set & {
		input: _run.output
		config: cmd: ["ruby", "/app/json_parse.rb"]
	}

	// Resulting container image
	image: _set.output
}

dagger.#Plan & {
	client: {
		filesystem: {
			"./src/instance_lists.json": write: contents:	actions.prepare.export.files["/instance_lists.json"]
			"./src": read: contents:						dagger.#FS
		}
		network: "unix:///var/run/docker.sock": connect: dagger.#Socket
		env: {
			AWS_ACCESS_KEY_ID:	 dagger.#Secret
			AWS_SECRET_ACCESS_KEY: dagger.#Secret
		}
	}

	actions: {
		// get the name of an instance with a specific tag
		prepare: aws.#Container & {
			always:	true
			layer:	string | *"web"

			credentials: aws.#Credentials & {
				accessKeyId:	 client.env.AWS_ACCESS_KEY_ID
				secretAccessKey: client.env.AWS_SECRET_ACCESS_KEY
			}
			command: {
				name: "sh"
				flags: "-c": "aws ec2 describe-instances --debug --region=ap-northeast-1 --filters 'Name=tag:layer,Values=\(layer)' > /instance_lists.json"
			}
			_build: src: core.#Source & {
				path: "src"
			}
			export: files: "/instance_lists.json": _
		}

		// build an ruby image
		build: #ImageBuild & {
			app: client.filesystem."./src".read.contents
		}

		// push image to local registry
		// TODO: change to ECR from local
		push: docker.#Push & {
			image: build.image
			dest:  "localhost:5042/disp_instance_list"
		}

		// pull & exec container
		// TODO: development
	}
}
