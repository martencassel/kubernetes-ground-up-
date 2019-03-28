# kubernetes-ground-up-

```bash
#!/bin/sh

mkdir /tmp
mkdir -p /var/log/kubernetes 
sudo mkdir etcd-data

sudo -i 

docker run --volume=$PWD/etcd-data:/default.etcd \
    --detach \
    --net=host quay.io/coreos/etcd > etcd-container-id

/home/marten/src/kubernetes/_output/bin/kube-apiserver -v=7 \
    --etcd-servers=http://127.0.0.1:2379 \
    --log-dir=/var/log/kubernetes \
    --logtostderr=false \
    --feature-gates=ProcMountType=true

openssl req  -nodes -new -x509  -keyout sa.key -out sa.cert

/home/marten/src/kubernetes/_output/bin/kube-controller-manager \
    --kubeconfig /var/lib/kubelet/kubeconfig -v=8 \
    --log-dir=/var/log/kubernetes --logtostderr=false \
    --service-account-private-key-file=/tmp/sa.key \
    --feature-gates=ProcMountType=true

cat << EOF > /etc/kubernetes/kubelet.config
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
staticPodPath: /etc/kubernetes/manifests
failSwapOn: false
EOF

/home/marten/src/kubernetes/_output/bin/kubelet \
    --kubeconfig /var/lib/kubelet/kubeconfig \
    --log-dir=/var/log/kubernetes --alsologtostderr=false --logtostderr=false \
    --config=/etc/kubernetes/kubelet.config \
    -v=5 

curl http://localhost:8080/api/v1/nodes
curl --stderr /dev/null http://localhost:8080/api/v1/pods | jq '.items'

curl --stderr /dev/null http://localhost:8080/api/v1/nodes/ \
| jq '.items' | head


wget https://raw.githubusercontent.com/kamalmarhubi/kubernetes-from-the-ground-up/master/01-the-kubelet/nginx.yaml
sed --in-place '/spec:/a\ \ nodeName: thinkpad' nginx.yaml
head nginx.yaml

ruby -ryaml -rjson -e 'puts JSON.pretty_generate(YAML.load(ARGF))' < nginx.yaml > nginx.json


curl \
-H 'Content-Type: application/json' \
--stderr /dev/null \
--request POST http://localhost:8080/api/v1/namespaces/default/pods \
--data @nginx.json | jq 'del(.spec.containers, .spec.volumes)'

{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "pods \"nginx\" is forbidden: error looking up service account default/default: serviceaccount \"default\" not found",
  "reason": "Forbidden",
  "details": {
    "name": "nginx",
    "kind": "pods"
  },
  "code": 403
}

curl --stderr /dev/null http://localhost:8080/api/v1/namespaces/default/pods \
| jq '.items[] | { name: .metadata.name, status: .status} | del(.status.containerStatuses)'


cat << EOF > /tmp/img.yml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: img
  name: img
  annotations:
    container.apparmor.security.beta.kubernetes.io/img: unconfined
spec:
  nodeName: thinkpad
  securityContext:
    runAsUser: 1000
  initContainers:
    # This container clones the desired git repo to the EmptyDir volume.
    - name: git-clone
      image: r.j3ss.co/jq
      args:
        - git
        - clone
        - --single-branch
        - --
        - https://github.com/jessfraz/dockerfiles
        - /repo # Put it in the volume
      securityContext:
        procMount: "Unmasked"
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
      volumeMounts:
        - name: git-repo
          mountPath: /repo
  containers:
  - image: r.j3ss.co/img
    imagePullPolicy: Always
    name: img
    resources: {}
    workingDir: /repo
    command:
    - img
    - build
    - -t
    - irssi
    - irssi/
    securityContext:
      procMount: "Unmasked"
      capabilities:
        add:
        - SYS_ADMIN
    volumeMounts:
    - name: cache-volume
      mountPath: /tmp
    - name: git-repo
      mountPath: /repo
  volumes:
  - name: cache-volume
    emptyDir: {}
  - name: git-repo
    emptyDir: {}
  restartPolicy: Never
EOF
  
ruby -ryaml -rjson -e 'puts JSON.pretty_generate(YAML.load(ARGF))' < /tmp/img.yml > /tmp/img.json

curl \
-H 'Content-Type: application/json' \
--stderr /dev/null \
--request POST http://localhost:8080/api/v1/namespaces/default/pods \
--data @/tmp/img.json | jq 'del(.spec.containers, .spec.volumes)'
  
curl --stderr /dev/null http://localhost:8080/api/v1/namespaces/default/pods \
| jq '.items[] | { name: .metadata.name, status: .status} | del(.status.containerStatuses)'

root@thinkpad:~# docker logs 5f7
Cloning into '/repo'...
fatal: unable to access 'https://github.com/jessfraz/dockerfiles/': Could not resolve host: github.com
root@thinkpad:~# kubectl describe po/img
Name:               img
Namespace:          default
Priority:           0
PriorityClassName:  <none>
Node:               thinkpad/172.20.10.4
Start Time:         Thu, 28 Mar 2019 16:37:41 +0100
Labels:             run=img
Annotations:        container.apparmor.security.beta.kubernetes.io/img: unconfined
Status:             Failed
IP:                 172.17.0.3
Init Containers:
  git-clone:
    Container ID:  docker://5f7becf7033ae7c57c31253b1016c9cff8b58d5c5422455e83a2d48ba964a8cc
    Image:         r.j3ss.co/jq
    Image ID:      docker-pullable://r.j3ss.co/jq@sha256:357e34b48cd1a6458242f8a2d494d776c286a8e161243ce0feba4f051cce4fe5
    Port:          <none>
    Host Port:     <none>
    Args:
      git
      clone
      --single-branch
      --
      https://github.com/jessfraz/dockerfiles
      /repo
    State:          Terminated
      Reason:       Error
      Exit Code:    128
      Started:      Thu, 28 Mar 2019 16:37:46 +0100
      Finished:     Thu, 28 Mar 2019 16:37:51 +0100
    Ready:          False
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /repo from git-repo (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-bsq2d (ro)
Containers:
  img:
    Container ID:  
    Image:         r.j3ss.co/img
    Image ID:      
    Port:          <none>
    Host Port:     <none>
    Command:
      img
      build
      -t
      irssi
      irssi/
    State:          Waiting
      Reason:       PodInitializing
    Ready:          False
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /repo from git-repo (rw)
      /tmp from cache-volume (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-bsq2d (ro)
Conditions:
  Type              Status
  Initialized       False 
  Ready             False 
  ContainersReady   False 
  PodScheduled      True 
Volumes:
  cache-volume:
    Type:    EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:  
  git-repo:
    Type:    EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:  
  default-token-bsq2d:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-bsq2d
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type     Reason             Age                   From               Message
  ----     ------             ----                  ----               -------
  Normal   Pulling            4m5s                  kubelet, thinkpad  Pulling image "r.j3ss.co/jq"
  Normal   Pulled             4m1s                  kubelet, thinkpad  Successfully pulled image "r.j3ss.co/jq"
  Normal   Created            4m1s                  kubelet, thinkpad  Created container git-clone
  Normal   Started            4m1s                  kubelet, thinkpad  Started container git-clone
  Warning  MissingClusterDNS  3m59s (x4 over 4m5s)  kubelet, thinkpad  pod: "img_default(6cc8938d-516f-11e9-80ef-e86a647ebe1b)". kubelet does not have ClusterDNS IP configured and cannot create Pod using "ClusterFirst" policy. Falling back to "Default" policy.
root@thinkpad:~# 

root@thinkpad:~# docker ps
CONTAINER ID        IMAGE                  COMMAND                  CREATED             STATUS              PORTS               NAMES
c0a4188c9c86        busybox                "/bin/sh -c 'while t…"   About an hour ago   Up About an hour                        k8s_log-truncator_nginx_default_432e00bd-5169-11e9-9612-e86a647ebe1b_0
7beb93103815        nginx                  "nginx -g 'daemon of…"   About an hour ago   Up About an hour                        k8s_nginx_nginx_default_432e00bd-5169-11e9-9612-e86a647ebe1b_0
d7a2d0f24b3c        k8s.gcr.io/pause:3.1   "/pause"                 About an hour ago   Up About an hour                        k8s_POD_nginx_default_432e00bd-5169-11e9-9612-e86a647ebe1b_0
56cb44f69204        quay.io/coreos/etcd    "/usr/local/bin/etcd"    3 hours ago         Up 3 hours                              condescending_tesla
root@thinkpad:~# docker exec -it c0a4 /bin/sh
/ # ls
bin     dev     etc     home    logdir  proc    root    sys     tmp     usr     var
/ # cat /etc/resolv.conf 
nameserver 127.0.0.53
options edns0
/ # 

root@thinkpad:~# cat /etc/resolv.conf 
# This file is managed by man:systemd-resolved(8). Do not edit.
#
# This is a dynamic resolv.conf file for connecting local clients to the
# internal DNS stub resolver of systemd-resolved. This file lists all
# configured search domains.
#
# Run "resolvectl status" to see details about the uplink DNS servers
# currently in use.
#
# Third party programs must not access this file directly, but only through the
# symlink at /etc/resolv.conf. To manage man:resolv.conf(5) in a different way,
# replace this symlink by a static file or a different symlink.
#
# See man:systemd-resolved.service(8) for details about the supported modes of
# operation for /etc/resolv.conf.

nameserver 127.0.0.53
options edns0
root@thinkpad:~# 

```
```
