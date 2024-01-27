# Skoupidia

Your home machine learning cluster made from rubbish and things found 'round the house.

![Oscar the Grouch making Science from Skoupidia](./docs/a_oscar.png)
![using the terminal](./docs/b_terminal.png)
![and a bunch of skoupidia!](./docs/c_cluster.jpg)

1. [Create A Kubernetes Cluster](#create-a-kubernetes-cluster)
1. [Install Kubeflow](#install-kubeflow)
1. [My Own Personal Setup](#my-own-personal-setup)
1. [References](#references)

## Create A Kubernetes Cluster

### Create Autobot User

On each of the servers, create a user named `autobot`. This will be the user ansible will use to install and remove software:

```bash
sudo adduser autobot
sudo usermod -aG sudo autobot
```

Autobot has now been added to the sudo group, but to make ansible less of a pain, remove the need to interactively type the password every time autobot changes to run a command as root.

```bash
sudo su
echo "autobot ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/peeps
```

#### Generate an SSH key locally

You can do this a number of ways, but here is an easy version:

```bash
ssh-keygen -f ~/.ssh/home-key -t rsa -b 4096
```

or you can use the premade task

```bash
make ssh_keys
```

This will, by default save the public and private keys into your `~/.ssh` directory.

We want to take the `.pub` (public) key from our local server, and add the contents of the pub key to the file `~/.ssh/authorized_keys` on each of the servers in the `autobot` users home directory.

This will allow your local machine (or any machine that has the private key) to be able to automatically login to any of the nodes without typing a password. Again this will be very helpful when running the ansible scripts.

One way to do this is to copy the file contents to the clipboard:

```bash
xclip -selection clipboard < ~/.ssh/home-key.pub
```

Then ssh into the machine as user `autobot`, and paste the clipboard contents into the `~/.ssh/authorized_keys` file (or create the file if it doesn't already exist).

### Run Ansible Setups

We should now be ready to run the [anisble](./ansible/README.md) code.

The Anisble scripts will install some prerequisites, docker, and kubeadm and kubectl on the master and the worker nodes.

Follow along with the [README in the ansible directory](./ansible/README.md) to continue.

### Few Difficult to Script Tasks

Now that ansible had run completely, we need to do a few manual steps. Don't skip these!

You'll need to run these commands on all the nodes (master and workers). After ansible has finished without error.

```bash
sudo su
systemctl stop containerd
rm /etc/containerd/config.toml
# it's ok if that errors --^
containerd config default > /etc/containerd/config.toml
```

You'll need to use a text editor and set a value from `false` to `true`. 

Edit the file `/etc/containerd/config.toml`, and change the setting `SystemdCgroup = false` to `SystemdCgroup = true` in the section:

```toml
...
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    ...
    SystemdCgroup = true
...
```

---

**Note:** Adding GPUs to the config.toml https://github.com/NVIDIA/k8s-device-plugin#quick-start

---


This will enable the systemd cgroup driver for the containerd container runtime.

```bash
systemctl restart containerd
```

Run the following to pull down needed configurations for kubeadm

```bash
kubeadm config images pull
```

### Run Kube Init

Now, only on the designated **master** node, run

```bash
kubeadm init --v=5
```

If all goes well, the output of this command will give use the commands we can use on the worker nodes to join the cluster.

For example:

```bash
kubeadm join 192.168.1.15:6443 --token 3e...l --discovery-token-ca-cert-hash sha256:65...ec 
```

Save copy this command as we'll use this on the worker nodes to have the nodes join the master node.

It's a good idea to add the kube config to the autobot user so you can do things like `kubectl get nodes`. Run these as the autobot user:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Join Workers to Cluster

On each worker nodes run the join command (note your values will be slightly different)

```bash
kubeadm join 192.168.1.15:6443 --token 3eown3.mqv6a0p2pz3vd6il \
        --discovery-token-ca-cert-hash sha256:926d39ea23aab584720dd3cf846124dc4b08bddd2021b18252a8e7e9dee765ec
```

### Cluster Networking Using Calico

After the workers have joined the cluster, we should be able to see them:

```
autobot@kmaster:~$ kubectl get nodes
NAME       STATUS     ROLES           AGE     VERSION
kmaster    NotReady   control-plane   77m     v1.28.6
kworker1   NotReady   <none>          25m     v1.28.6
kworker2   NotReady   <none>          3m34s   v1.28.6
```

But we need to add container networking before they will be in the ready state

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
```

After applying calico, give the cluster some time to get all the node into the ready state.

```
autobot@kmaster:~$ kubectl get nodes -w
NAME       STATUS   ROLES           AGE   VERSION
kmaster    Ready    control-plane   91m   v1.28.6
kworker1   Ready    <none>          40m   v1.28.6
kworker2   Ready    <none>          17m   v1.28.6
```

We now have a working cluster!

### Add MetalLB

For up to date info see here: https://metallb.org/installation/ but in summary, we are going to install the loadbalancer:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

And then, associate your local IP pool to the local load balancer by editing an applying `kubernetes/metallb_stage2.yaml`.


### Add Some Storage

There are many ways to add storage to the cluster. For something more than just playing around in a home lab, have a look into [Minio][minio]. Minio creates a local storage system that is S3 compatible. This will allow any pod to use the storage. Here though, we are just using local disk storage.

This is quite specific to how you have disks setup, but here is an example on mine. I have an external USB drive plugged into the master node. It is already formatted and ready to go. First you need to find which `/dev` the USB is plugged into, and then you can create a folder and mount it:

```bash
lsblk
```

```bash
sudo mkdir /mnt/usbd
sudo mount /dev/sbd1 /mnt/usbd
sudo mkdir /mnt/usbc
sudo mount /dev/sdc1 /mnt/usbc
```

You should be able to see the contents of the drive now `ls /mnt/usbd`.

Once you have that working, you can add the listing to the `/etc/fstab` file so that it will mount again if you reboot the server:

```bash
sudo su
echo "/dev/sdb1 /mnt/usbd ext4 defaults 0 0" >> /etc/fstab
echo "/dev/sdc2 /mnt/usbc ext4 defaults 0 0" >> /etc/fstab
```

For example.

With the drive mounted, you can make a PersistentVolume definition

### Add Labels 

You can make sure different pods run on correct nodes by adding a label to the nodes and then using the `affinity` section of the spec. For example I label my slow drive nodes and the nodes with a gpu like so:

```bash
kubectl label nodes kmaster disktype=hdd
kubectl label nodes kworker1 disktype=ssd
kubectl label nodes kworker2 disktype=ssd
kubectl label nodes kworker1 has_gpu=true
kubectl label nodes kworker2 has_tpu=true
```

---

**Note:** use `accelerator=` with a type `example-gpu-x100` to mark nodes hardware

---

You can see the labels with

```bash
kubectl get nodes --show-labels
```

Then you can do something like:

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values:
              - hdd
```

```bash
kubectl -n default exec -it local-pv-pod -- /bin/bash
```

## Optional - Install Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

## Install Kubeflow

(tbd)

# My Own Personal Setup

Create my namespaces. I use `tools` for thinks like Jellyfin media server and utilities, and `science` for doing actual work.

```bash
kubectl apply -f https://raw.githubusercontent.com/robrohan/skoupidia/main/kubernetes/oscar/namespaces.yaml
```

I've already a mount point on all the nodes for scratch storage (`/mnt/kdata`). See the `local-pv-volume` for details. This will let pods claim some of that data.

```bash
kubectl apply -f https://raw.githubusercontent.com/robrohan/skoupidia/main/kubernetes/oscar/local-pv-volume.yaml
```

Those storage options get reused once the pod goes down, and are only useful for temporary storage. For longer term storage I have a few USB drives plugged into various nodes. I used these drives for local media for jellyfin, and when downloading / training machine learning models I want to keep around

```bash
kubectl apply -f https://raw.githubusercontent.com/robrohan/skoupidia/main/kubernetes/oscar/usb-pv-volume.yaml
```

Deployment of our local media server


```bash
kubectl apply -f https://raw.githubusercontent.com/robrohan/skoupidia/main/kubernetes/oscar/jellyfin.yaml
```

Deployment of my custom built Jupyter notebook install.


```bash
kubectl apply -f https://raw.githubusercontent.com/robrohan/skoupidia/main/kubernetes/oscar/jupyter.yaml
```

Create an S3 like (s3 compatible) storage service locally

```bash
kubectl apply -f https://raw.githubusercontent.com/robrohan/skoupidia/main/kubernetes/oscar/minio.yaml
```

Install the [CLI client](https://min.io/docs/minio/linux/reference/minio-mc.html) to interact with the buckets:

```bash
curl https://dl.min.io/client/mc/release/linux-amd64/mc --create-dirs -o $HOME/bin/mc
chmod u+x $HOME/bin/mc
mc --help
```

Example usage:

```bash
mc alias set oscar http://192.168.1.23:80 minio minio123  # setup the client
mc admin info myminio
mc mb oscar/test-bucket
mc ls oscar
```

This a just a utility I made to generate random MIDI files for musical inspiration and to feed into some models I am playing with (probably not interesting)

```bash
kubectl apply -f https://raw.githubusercontent.com/robrohan/skoupidia/main/kubernetes/oscar/songomatic.yaml
```

If a volume ever gets stuck, and you want to allow others to claim it, you can un-taint it like this:

```bash
kubectl patch pv usb-jelly-1-pv-volume -p '{"spec":{"claimRef": null}}'
```

# Troubleshooting 

## DNS

This is can be quite frustrating. I think this is just an Ubuntu thing. Inside a worker node, it will use the master node for DNS. The master node will look inside itself to resolve the DNS entry, but if it doesn't know the URL, it'll look in `/etc/resolv.conf` for a name server.

There are seemingly several process that overwrite that file from time to time which seems to kill resolution. The netplan process, resolvd process, and tailscale can over write it too. This is the process I've found that works, but if it gets to be too much of a problem, you can unlink the /etc/resolv.conf file and just edit it.

On kmaster node:

```bash
sudo vi /etc/systemd/resolved.conf

sudo unlink /etc/resolv.conf
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved
sudo systemctl enable systemd-resolved

sudo cat /etc/resolv.conf
```

# References

- [Build a Kubernetes Home Lab from Scratch step-by-step!](https://www.youtube.com/watch?v=_WW16Sp8-Jw)
- [How to Install Containerd Container Runtime on Ubuntu 22.04](https://www.howtoforge.com/how-to-install-containerd-container-runtime-on-ubuntu-22-04/)
- [How to with new stuff](https://v1-28.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [](https://blog.christianposta.com/kubernetes/logging-into-a-kubernetes-cluster-with-kubectl/)

[minio]: https://medium.com/@karrier_io/minio-s3-compatible-storage-on-kubernetes-74e2cf0902f3

