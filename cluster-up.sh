#!/usr/bin/env bash

GO_OUT=/home/marten/src/kubernetes/_output/bin
LOG_LEVEL=5
ETCD_HOST=127.0.0.1
ETCD_PORT=2379
FEATURE_GATES="ProcMountType=true"
LOG_DIR=/var/log/kubernetes
CONTROLPLANE_SUDO=$(echo "sudo -E")

rm /tmp/sa.*
openssl req -nodes -new -x509  -keyout /tmp/sa.key -out /tmp/sa.cert -subj '/CN=www.mydom.com/O=My Company Name LTD./C=US'

kill `pidof kube-apiserver`
kill `pidof kube-controller-manager`
kill `pidof kube-scheduler`
kill `pidof kubelet`

function start_etcd {
    echo "Starting etcd"
    sudo mkdir etcd-data
    docker run --volume=$PWD/etcd-data:/default.etcd \
    --detach --net=host quay.io/coreos/etcd > etcd-container-id
}

function start_apiserver {
    echo "Starting apiserver"
    APISERVER_LOG=${LOG_DIR}/kube-apiserver.log
    touch $APISERVER_LOG

    ${CONTROLPLANE_SUDO} "${GO_OUT}/kube-apiserver" \
    --v=${LOG_LEVEL} \
    --etcd-servers="http://${ETCD_HOST}:${ETCD_PORT}" \
    --feature-gates="${FEATURE_GATES}" > "${APISERVER_LOG}" 2>&1 &
}

function start_controller_manager {
    echo "Starting controller manager"
    CTRLMGR_LOG=${LOG_DIR}/kube-controller-manager.log
    ${CONTROLPLANE_SUDO} "${GO_OUT}/kube-controller-manager" \
    -v=${LOG_LEVEL} \
    --service-account-private-key-file="${SERVICE_ACCOUNT_KEY}" \
    --feature-gates="${FEATURE_GATES}" \
    --master="http://localhost:8080" > "${CTRLMGR_LOG}" 2>&1 &
}

function start_kubescheduler {
    cat <<EOF > /tmp/scheduler.kubeconfig
apiVersion: v1
clusters:
- cluster:
    server: http://127.0.0.1:8080
EOF

    echo "Starting kubescheduler"
    SCHEDULER_LOG=${LOG_DIR}/kube-scheduler.log
    ${CONTROLPLANE_SUDO} "${GO_OUT}/kube-scheduler" \
    -v=${LOG_LEVEL} \
    --kubeconfig /tmp/scheduler.kubeconfig \
    --feature-gates="${FEATURE_GATES}" \
    --master="http://localhost:8080" > "${SCHEDULER_LOG}" 2>&1 &
}

function start_kubelet {
    cat <<EOF > /tmp/kubeconfig
apiVersion: v1
clusters:
- cluster:
    server: http://127.0.0.1:8080
EOF
    cat <<EOF > /tmp/kubelet.config
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
staticPodPath: /etc/kubernetes/manifests
failSwapOn: false
EOF
    echo "Starting kubelet"
    KUBELET_LOG=${LOG_DIR}/kubelet.log
    ${CONTROLPLANE_SUDO} "${GO_OUT}/kubelet" \
    -v=${LOG_LEVEL} \
    --kubeconfig /tmp/kubeconfig \
    --config=/tmp/kubelet.config \
    --resolv-conf=/run/systemd/resolve/resolv.conf > "${KUBELET_LOG}" 2>&1 &
}


echo "Starting services now!"
start_etcd
start_apiserver
start_controller_manager
start_kubescheduler
start_kubelet

kubectl get componentstatuses

kubectl -v=8 get node
curl http://localhost:8080/api/v1/nodes

