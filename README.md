# Skoupidia

Your home machine learning cluster made from rubbish and things found 'round the house.

## ...

### Create Autobot User

On each all of the servers, create the user `autobot`. This will be the user ansible will use to install and remove software:

```
sudo adduser autobot
sudo usermod -aG sudo autobot
```

Autobot has now been added to the sudo group, but to make ansible less of a pain, remove the need to interactively type the password everytime autobot needs to run a root command.

```
sudo su
echo "autobot ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/peeps
```

### Generate an SSH key locally

You can do this a number of ways...

```bash
ssh-keygen -f ~/.ssh/home-key -t rsa -b 4096
```

or

```bash
make ssh_keys
```

This will, by default save the public and private keys into your `~/.ssh` directory. 

We want to take the `.pub` key from our local server, and add the contents of the pub key to the file `~/.ssh/authorized_keys` on each of the servers in the `autobot` users home directory.

This will allow your local machine (or any machine that has the private key) to be able to automaically login to any of the nodes without typing a password. Again this will be very helpful when running the ansible scripts.

One way to do this is to copy the file contents to the clipboard

```
xclip -selection clipboard < ~/.ssh/home-key.pub
```

Then ssh into the machine as user `autobot`, and paste the clipboard contents into the `~/.ssh/authorized_keys` file (or make it if it doesn't exist).

----

We should now be ready to run the [anisble](./ansible/README.md) code.
