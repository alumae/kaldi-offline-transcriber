## Introduction

This Dockerfile builds a pre-configured Docker image for Estonian "general-purpose" speech recognition.
In addition to speech-to-text, punctuation and speaker identification is also performed.
Speaker identification models are built for persons who often appear in Estonian broadcast news.

## Installation

The prebuilt image is available on http://canister.io. The image is 9.35 GB, which might be
the reason why I couln't push the image to Docker Hub. 

Unfortunately it seems that canister.io doesn't allow public repositories. Therefore,
in order to pull the image, you first have to login to canister.io using my "deploy key":

    docker login --username=deploy+alumae --password=b56047eb6701b59526e81b3c cloud.canister.io:5000
  
Then you can pull the image:

    docker pull cloud.canister.io:5000/alumae/kaldi-offline-transcriber-et

## Usage

Start ta container (name is "speech2test") and put it into background (`-d`). Also, mount a local
directory `~/tmp/speechfiles` as the container directory `/opt/speechfiles`.
  
    mkdir -p ~/tmp/speechfiles
    docker run --name speech2text -v ~/tmp/speechfiles:/opt/speechfiles --rm -d -t cloud.canister.io:5000/alumae/kaldi-offline-transcriber-et

  
  
In order to transcribe a file, you have to place it to `~/tmp/speechfiles` in your host machine
and then invoke the `/opt/kaldi-offline-transcriber/speech2text.sh` inside the Docker container 
to transcribe the file. Note that the `~/tmp/speechfiles` is equivalent to `/opt/speechfiles` from the
container perspective.

Example:
  
	cd ~/tmp/speechfiles
	wget http://media.kuku.ee/intervjuu/intervjuu2018080910.mp3
	# Note that you have to specify file paths from container's perspective
	docker exec -it speech2text /opt/kaldi-offline-transcriber/speech2text.sh --trs /opt/speechfiles/intervjuu2018080910.trs /opt/speechfiles/intervjuu2018080910.mp3

The result (in Transcriber XML format) is now in ~/tmp/speechfiles/intervjuu2018080910.trs:

	tail ~/tmp/speechfiles/intervjuu2018080910.trs
	</Turn>
	<Turn speaker="S1" startTime="268.11" endTime="298.79">
	<Sync time="268.11"/>
	eelmine aasta oli tegelikult selline lugu et jäi Balti matš ära Balti matš on toimub see aasta neljakümne teist korda selle aja jooksul on paar korda ära jäänud eelmine aasta oli Leedul üks niisugune asi mille pärast ta korraldada ei saanud ja eelmine aasta eelmine aasta ära ülemine aastal Eesti meeskondlikult
	<Sync time="286.71"/>
	kolmas aga väga tublid olid Eesti tüdrukud nii et et me just paistame sellega silma et et Eestis just nii-öelda tüdrukud ja naised on aktiivsed ja tegelevad selle tuletõrjespordiga
	</Turn>
	</Section>
	</Episode>
	</Trans>
