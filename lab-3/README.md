# Kubernetes/Calico Lab with dual-attach servers

NOTE: You will need Calico Enterprise to run this lab. Copy your config.json into ansible-k8s folder. That will be used by Ansible to create a secret, which will be used to download the Calico Enterprise node images.


### Lab setup

Spine layer - spine1, spine2
Rack1 - leaf10, leaf11, k8s-master
Rack2 - leaf20, leaf21, k8s-worker-1


Loopbacks for the leaf and spine switches - 172.16.255.x
Loopbacks for master and workers - 192.168.20x.1

Rack1 node CIDR - 10.50.1.0/24, 10.50.2.0/24
Rack2 node CIDR - 10.50.3.0/24, 10.50.4.0/24

You need ~4 CPU and ~12GB+ RAM to run this lab on your computer. Make sure to have virtualbox, and ansible. I have tested this on Ubuntu 18.04 laptop with latest stable versions.



### First run

vagrant up leaf10 leaf11 leaf20 leaf21 spine1 spine2 k8s-master k8s-worker-1

This will set up unnumbered BGP between fabric switches. There will be NO BGP between leaf and rack. So there are static routes configured on nodes and fabric to be able to reach each other and have a working kubernetes/calico.

Review the setup.

```
b-3 git:(master) ✗ vagrant ssh k8s-master
...
vagrant@k8s-master:~$ kubectl get node -o wide
NAME           STATUS   ROLES    AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
k8s-master     Ready    master   69m   v1.18.1   192.168.200.1   <none>        Ubuntu 18.04.4 LTS   4.15.0-76-generic   docker://19.3.8
k8s-worker-1   Ready    <none>   66m   v1.18.1   192.168.201.1   <none>        Ubuntu 18.04.4 LTS   4.15.0-76-generic   docker://19.3.8
vagrant@k8s-master:~$ 
...
vagrant@k8s-master:~$ kubectl get po -A -owide
NAMESPACE           NAME                                         READY   STATUS    RESTARTS   AGE   IP              NODE           NOMINATED NO
DE   READINESS GATES
calico-system       calico-kube-controllers-7f95545d84-t68z6     1/1     Running   0          69m   10.10.235.194   k8s-master     <none>      
     <none>
calico-system       calico-node-599ds                            1/1     Running   0          69m   192.168.200.1   k8s-master     <none>      
     <none>
calico-system       calico-node-dzfvc                            1/1     Running   0          67m   192.168.201.1   k8s-worker-1   <none>      
     <none>
calico-system       calico-typha-64ffdd88b5-7z9sc                1/1     Running   0          69m   192.168.200.1   k8s-master     <none>      
     <none>
calico-system       calico-typha-64ffdd88b5-fg9wd                1/1     Running   0          67m   192.168.201.1   k8s-worker-1   <none>      
     <none>
kube-system         coredns-66bff467f8-578tg                     1/1     Running   0          69m   10.10.235.195   k8s-master     <none>      
     <none>
kube-system         coredns-66bff467f8-647mw                     1/1     Running   0          69m   10.10.235.193   k8s-master     <none>      
     <none>
kube-system         etcd-k8s-master                              1/1     Running   0          69m   192.168.200.1   k8s-master     <none>      
     <none>
kube-system         kube-apiserver-k8s-master                    1/1     Running   0          69m   192.168.200.1   k8s-master     <none>      
     <none>
kube-system         kube-controller-manager-k8s-master           1/1     Running   0          69m   192.168.200.1   k8s-master     <none>      
     <none>
kube-system         kube-proxy-klqx8                             1/1     Running   0          67m   192.168.201.1   k8s-worker-1   <none>      
     <none>
kube-system         kube-proxy-wg5wf                             1/1     Running   0          69m   192.168.200.1   k8s-master     <none>      
     <none>
kube-system         kube-scheduler-k8s-master                    1/1     Running   0          69m   192.168.200.1   k8s-master     <none>      
     <none>
tigera-operator     tigera-operator-84644cc5b8-5pw6g             1/1     Running   0          69m   192.168.200.1   k8s-master     <none>      
     <none>
tigera-prometheus   calico-prometheus-operator-588fdd8d9-wsj9z   1/1     Running   0          69m   10.10.235.192   k8s-master     <none>      
     <none>
tigera-system       tigera-apiserver-67b87557db-kd5gp            2/2     Running   0          67m   10.10.235.196   k8s-master     <none>      
     <none>
vagrant@k8s-master:~$
```

So we have the nodes ready and pods running tied to loopback.

```
vagrant@k8s-master:~$ sudo calicoctl node status
Calico process is running.

IPv4 BGP status
+---------------+-------------------+-------+----------+-------------+
| PEER ADDRESS  |     PEER TYPE     | STATE |  SINCE   |    INFO     |
+---------------+-------------------+-------+----------+-------------+
| 192.168.201.1 | node-to-node mesh | up    | 16:14:50 | Established |
+---------------+-------------------+-------+----------+-------------+

IPv6 BGP status
No IPv6 peers found.

vagrant@k8s-master:~$ 
```

Calico BGP peering is node-to-node. We need to change it to peer with fabric. After that we can disable the static routes and advertise the loopback from the node.

```
vagrant@k8s-master:~$ sudo calicoctl node status                                                                                               
Calico process is running.                                                                                                                     
                                                                                                                                               
IPv4 BGP status                                                                                                                                
+---------------+-------------------+-------+----------+-------------+                                                                         
| PEER ADDRESS  |     PEER TYPE     | STATE |  SINCE   |    INFO     |                                                                         
+---------------+-------------------+-------+----------+-------------+                                                                         
| 192.168.201.1 | node-to-node mesh | up    | 16:14:50 | Established |                                                                         
+---------------+-------------------+-------+----------+-------------+                                                                         
                                                                                                                                               
IPv6 BGP status                                                                                                                                
No IPv6 peers found.                                                                                                                           
                                                                                                                                               
vagrant@k8s-master:~$                                                                                                                          
vagrant@k8s-master:~$ calicoctl get node -o yaml                                                                                               
Failed to create Calico API client: stat /home/ubuntu/.kube/config: no such file or directory                                                  
vagrant@k8s-master:~$ # Update the /etc/calico/calicoctl.cfg to point to right config, change ubuntu to vagrant                                
vagrant@k8s-master:~$ sudo vi /etc/calico/calicoctl.cfg                                                                                        
vagrant@k8s-master:~$ calicoctl get node -o yaml
vagrant@k8s-master:~$ calicoctl get node -o yaml | grep "  spec:" -A5
  spec:
    bgp:
      ipv4Address: 192.168.200.1/32
- apiVersion: projectcalico.org/v3
  kind: Node
  metadata:
--
  spec:
    bgp:
      ipv4Address: 192.168.201.1/32
kind: NodeList
metadata: {}
vagrant@k8s-master:~$ calicoctl patch node k8s-master -p '{"spec":{"bgp": {"asNumber": "65101"}}}'
Successfully patched 1 'Node' resource
vagrant@k8s-master:~$ calicoctl patch node k8s-worker-1 -p '{"spec":{"bgp": {"asNumber": "65102"}}
Successfully patched 1 'Node' resource
vagrant@k8s-master:~$ calicoctl get node -o yaml | grep "  spec:" -A5
  spec:
    bgp:
      asNumber: 65101
      ipv4Address: 192.168.200.1/32
- apiVersion: projectcalico.org/v3
  kind: Node
--
  spec:
    bgp:
      asNumber: 65102
      ipv4Address: 192.168.201.1/32
kind: NodeList
metadata: {}
vagrant@k8s-master:~$ 
vagrant@k8s-master:~$ kubectl get node --show-labels
NAME           STATUS   ROLES    AGE   VERSION   LABELS
k8s-master     Ready    master   78m   v1.18.1   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.
io/hostname=k8s-master,kubernetes.io/os=linux,node-role.kubernetes.io/master=
k8s-worker-1   Ready    <none>   76m   v1.18.1   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.
io/hostname=k8s-worker-1,kubernetes.io/os=linux
vagrant@k8s-master:~$ kubectl label node k8s-master rack=rack1
node/k8s-master labeled
vagrant@k8s-master:~$ kubectl label node k8s-worker-1 rack=rack2
node/k8s-worker-1 labeled
vagrant@k8s-master:~$ kubectl get node --show-labels
NAME           STATUS   ROLES    AGE   VERSION   LABELS
k8s-master     Ready    master   79m   v1.18.1   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.
io/hostname=k8s-master,kubernetes.io/os=linux,node-role.kubernetes.io/master=,rack=rack1
k8s-worker-1   Ready    <none>   77m   v1.18.1   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.
io/hostname=k8s-worker-1,kubernetes.io/os=linux,rack=rack2
vagrant@k8s-master:~$ 
```

So we have patched the master and worker nodes and added the labels. Now let us create the BGP peers for each.

```
vagrant@k8s-master:~$ kubectl apply -f - <<EOF
> ---
> # BGP peer configuration.
> 
> apiVersion: projectcalico.org/v3
> kind: BGPPeer
> metadata:
>   name: rack1-tor1
> spec:
>   peerIP: 10.50.1.1
>   asNumber: 65101
>   nodeSelector: rack == 'rack1'
>   sourceAddress: None
>   failureDetectionMode: BFDIfDirectlyConnected
>   restartMode: LongLivedGracefulRestart
>   birdGatewayMode: DirectIfDirectlyConnected
> ---
> apiVersion: projectcalico.org/v3
> kind: BGPPeer
> metadata:
>   name: rack1-tor2
> spec:
>   peerIP: 10.50.2.1
>   asNumber: 65101
>   nodeSelector: rack == 'rack1'
>   sourceAddress: None
>   failureDetectionMode: BFDIfDirectlyConnected
>   restartMode: LongLivedGracefulRestart
>   birdGatewayMode: DirectIfDirectlyConnected
> ---
> EOF
bgppeer.projectcalico.org/rack1-tor1 created
bgppeer.projectcalico.org/rack1-tor2 created
vagrant@k8s-master:~$ 

bgppeer.projectcalico.org/rack1-tor2 created
vagrant@k8s-master:~$ kubectl apply -f - <<EOF
> 
> apiVersion: projectcalico.org/v3
> kind: BGPPeer
> metadata:
>   name: rack2-tor1
> spec:
>   peerIP: 10.50.3.1
>   asNumber: 65102
>   nodeSelector: rack == 'rack2'
>   sourceAddress: None
>   failureDetectionMode: BFDIfDirectlyConnected
>   restartMode: LongLivedGracefulRestart
>   birdGatewayMode: DirectIfDirectlyConnected
> ---
> apiVersion: projectcalico.org/v3
> kind: BGPPeer
> metadata:
>   name: rack2-tor2
> spec:
>   peerIP: 10.50.4.1
>   asNumber: 65102
>   nodeSelector: rack == 'rack2'
>   sourceAddress: None
>   failureDetectionMode: BFDIfDirectlyConnected
>   restartMode: LongLivedGracefulRestart
>   birdGatewayMode: DirectIfDirectlyConnected
> ---
> 
> EOF
```

The commands above are in bgpconfig.yaml file on master node, so it's easy to copy/paste. NOTE: you may need to download appropriate calicoctl for enterprise use. I used kubectl to apply.

Let us disable full-mesh and restart calicpo-node.

-master:~$ calicoctl apply -f - <<EOF
> apiVersion: projectcalico.org/v3
> kind: BGPConfiguration
> metadata:
>   name: default
> spec:
>   logSeverityScreen: Info
>   nodeToNodeMeshEnabled: false
> 
> ---
> EOF
Successfully applied 1 'BGPConfiguration' resource(s)
vagrant@k8s-master:~$ sudo calicoctl node status
Calico process is running.

IPv4 BGP status
+--------------+---------------+-------+----------+-------------+
| PEER ADDRESS |   PEER TYPE   | STATE |  SINCE   |    INFO     |
+--------------+---------------+-------+----------+-------------+
| 10.50.1.1    | node specific | up    | 17:34:33 | Established |
| 10.50.2.1    | node specific | up    | 17:34:33 | Established |
+--------------+---------------+-------+----------+-------------+

IPv6 BGP status
No IPv6 peers found.

vagrant@k8s-master:~$ 
vagrant@k8s-master:~$ kubectl delete po -n kube-system -l k8s-app=kube-dns
pod "coredns-66bff467f8-578tg" deleted
pod "coredns-66bff467f8-647mw" deleted
vagrant@k8s-master:~$ kubectl get po -n kube-system -owide -l k8s-app=kube-dns
NAME                       READY   STATUS    RESTARTS   AGE   IP            NODE           NOMINATED NODE   READINESS GATES
coredns-66bff467f8-4mjs6   1/1     Running   0          33s   10.10.230.0   k8s-worker-1   <none>           <none>
coredns-66bff467f8-4xlcz   1/1     Running   0          34s   10.10.230.1   k8s-worker-1   <none>           <none>
vagrant@k8s-master:~$ 

```

So we are able to schedule pods on worker node. Now remember that we had set up static routes for bootstrapping. Need to disable that.

```
vagrant@leaf-sw10:mgmt:~$ sudo net show route static 
sudo: unable to resolve host leaf-sw10.lab.local: Name or service not known
RIB entry for static
====================
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, D - SHARP,
       F - PBR, f - OpenFabric,
       > - selected route, * - FIB route, q - queued route, r - rejected route

S>* 192.168.200.1/32 [1/0] via 10.50.1.10, VLAN10, 01:42:22 
vagrant@leaf-sw10:mgmt:~$ 
vagrant@leaf-sw10:mgmt:~$ 
vagrant@leaf-sw10:mgmt:~$ sudo net del routing route 192.168.200.1/32 10.50.1.10
sudo: unable to resolve host leaf-sw10.lab.local: Name or service not known
RIB entry for static
==================== 
vagrant@leaf-sw10:mgmt:~$ 
```

Repeat the same for every leaf switches.

```
vagrant@k8s-master:~$ kubectl get node -o wide
NAME           STATUS     ROLES    AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
k8s-master     Ready      master   99m   v1.18.1   192.168.200.1   <none>        Ubuntu 18.04.4 LTS   4.15.0-76-generic   docker://19.3.8
k8s-worker-1   NotReady   <none>   97m   v1.18.1   192.168.201.1   <none>        Ubuntu 18.04.4 LTS   4.15.0-76-generic   docker://19.3.8
vagrant@k8s-master:~$ 
```

As expected, the worker is not ready, as the fabric does not know the route to loopback.

Let us advertise the loopback.

```
vagrant@k8s-master:~$ kubectl get ippool
NAME                  AGE
default-ipv4-ippool   99m
vagrant@k8s-master:~$ kubectl apply -f - <<EOF
> apiVersion: projectcalico.org/v3
> kind: IPPool
> metadata:
>   name: loopbacks-rack-a
> spec:
>   cidr: 192.168.200.1/32
>   disabled: True
>   nodeSelector: rack == 'rack1'
> ---
> apiVersion: projectcalico.org/v3
> kind: IPPool
> metadata:
>   name: loopbacks-rack-b
> spec:
>   cidr: 192.168.201.1/32
>   disabled: True
>   nodeSelector: rack == 'rack2'
> ---
> EOF
ippool.projectcalico.org/loopbacks-rack-a created
ippool.projectcalico.org/loopbacks-rack-b created
vagrant@k8s-master:~$ 

vagrant@k8s-master:~$ kubectl get node -o wide
NAME           STATUS   ROLES    AGE    VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
k8s-master     Ready    master   102m   v1.18.1   192.168.200.1   <none>        Ubuntu 18.04.4 LTS   4.15.0-76-generic   docker://19.3.8
k8s-worker-1   Ready    <none>   100m   v1.18.1   192.168.201.1   <none>        Ubuntu 18.04.4 LTS   4.15.0-76-generic   docker://19.3.8
vagrant@k8s-master:~$ 

# On a leaf switch, you can see the /26 blocks
vagrant@leaf-sw20:mgmt:~$ sudo net show route | more
show ip route
=============
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, D - SHARP,
       F - PBR, f - OpenFabric,
       > - selected route, * - FIB route, q - queued route, r - rejected route

B>* 10.10.230.0/26 [200/0] via 10.50.3.10, VLAN10, 00:18:26
  *                        via fe80::a00:27ff:fe7e:a87d, swp4, 00:18:26
B>* 10.10.235.192/26 [20/0] via fe80::a00:27ff:fefb:9494, swp1, 00:20:09
```

As expected, the master gets ready as soon as you advertise the loopback. Need to address an outstanding issue (might be a config), where ALL the loopbacks are being advertised by ALL the nodes, even if we put the nodeselector. This is work-in-progress, might be just a config issue with BGP.











