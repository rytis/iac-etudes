* Build Nomad cluster
  * Three server nodes that also act as worker nodes
  * Three worker nodes
* Server nodes running on public network
* Nomad UI accessible through a load balancer
* Nomad cluster discovery (server and worker nodes) done using `go-discover` based on instance tags
