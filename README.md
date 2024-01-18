# Skoupidia

Your home machine learning cluster made from rubbish and things found 'round the house.

## ...

### Create Autobot User

On each all of the servers, create the user `autobot`. This will be the user ansible will use to install and remove software:

```
sudo adduser autobot
sudo usermod -aG sudo autobot
```

### Generate an SSH key locally

```
ssh-keygen -t ed25519 -C "your_email@example.com"
```

This will, by default save the public and private keys into your `~/.ssh` directory. 

We want to take the `.pub` key from our local server, and add the contents of the pub key to the file `~/.ssh/authorized_keys` on each of the servers in the `autobot` users home directory. 

This will allow your local machine (or any machine that has the private key) to be able to automaically login to any of the nodes without typing a password. Again this will be very helpful when running the ansible scripts.

One way to do this is to copy the file contents to the clipboard

```
xclip -selection clipboard < ~/.ssh/home-key.pub
```

Then ssh into the machine as user `autobot`, and paste the clipboard contents into the `~/.ssh/authorized_keys` file (or make it if it doesn't exist).

### (Optional) Disable Password Login

Once the keys are setup, it's a good idea to disable the ability to login with a password. However, since this is only for your local lab, it's really up to you.

---

⚠️ **WARNING** After this change you will not be able to ssh in with a password.

---

```
echo "autobot ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/peeps
```

We should now be ready to run the [anisble](./ansible/README.md) code.
