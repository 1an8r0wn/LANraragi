# Docker

A Docker image exists for deploying LANraragi installs to your machine easily without disrupting your already-existing web server setup.  
It also allows for easy installation on Windows/Mac !

## Cloning the base LRR image

Download [the Docker setup](https://www.docker.com/products/docker) and install it. Once you're done, execute:

```bash
docker run --name=lanraragi -p 3000:3000 \
-e LRR_UID=`id -u $USER` \
--mount type=bind,source=[YOUR_CONTENT_DIRECTORY],\
target=/home/koyomi/lanraragi/content difegue/lanraragi
```

{% hint style="info" %}
You can tell Docker to auto-restart the LRR container on boot by adding the `--restart always` flag to this command.
{% endhint %}

{% hint style="info" %}
If you're running on Windows, please check the syntax for mapping your content directory [here](https://docs.docker.com/docker-for-windows/#shared-drives).
{% endhint %}

The content directory you have to specify in the command above will contain archives you either upload through the software or directly drop in, alongside generated thumbnails. Subdirectories are supported. \(Standard behavior\)

It will also house the LANraragi database\(As database.rdb\). This is **exclusive** to the Docker installation, as it allows the user to hotswap containers without losing any data.

Docker can only access drives you allow it to, so if you want to setup in a folder on another drive, be sure to give Docker access to it.

Once your LANraragi container is loaded, you can access it at [http://localhost:3000](http://localhost:3000) .  
You can use the following commands to stop/start/remove the container\(Removing it won't delete the archive directory you specified\) :

```bash
docker stop lanraragi
docker start lanraragi
docker rm lanraragi
```

{% hint style="warning" %}
Windows 7/8 users running the Legacy Docker toolbox will have to explicitly forward port 127.0.0.1:3000 from the host to the vm in order to be able to access the app. (told ya to use vagrant)
{% endhint %}

The previous command doesn't specify a version, so Docker will by default pull the _latest_ tag, which matches the latest stable release.

[Tags](https://hub.docker.com/r/difegue/lanraragi/tags/) exist for major releases, so you can use those if you want to run another version:  
`docker run [yadda yadda] difegue/lanraragi:0.4.0`

{% hint style="danger" %}
If you're feeling **extra dangerous**, you can run the last files directly from the _dev_ branch of the Git repo through the _nightly_ tag:  
`docker run [zoinks] difegue/lanraragi:nightly`
{% endhint %}

## Changing the port

Since Docker allows for port mapping, you can most of times map the default port of 3000 to another port on your host quickly.  
If you need something a bit more involved \(like adding SSL\), please check the Network Interfaces section.

{% page-ref page="../advanced-usage/network-interfaces.md" %}

## Changing the user

The container runs the software by default under the _koyomi_ user, which can be modified by the LRR_USER environment variable.
`docker run [wassup] -e lrr_user=karen difegue/lanraragi`

{% hint style="warning" %}
The user will be changed using `setuid` only. This does not start a login shell and does not change environment variables like USER or HOME.
{% endhint %}

## Building your own

The previous setup gets a working LANraragi container from the Docker Hub, but you can build your own bleeding edge version by executing `npm run docker-build` from a cloned Git repo.

This will use your cloned Git repo to build the image, modifications you might have made included.

Of course, this requires a Docker installation.  
If you're running WSL\(which can't run Docker natively\), you can directly use the Docker for Windows executable with a simple symlink:

```bash
sudo ln -s '/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe' \
/usr/local/bin/docker
```

