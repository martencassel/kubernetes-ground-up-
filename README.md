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
```
