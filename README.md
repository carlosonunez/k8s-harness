# k8s-harness

🚀 Test your apps in disposable, prod-like Kubernetes clusters 🚀

[[ _insert gif here when ready_ ]]

## But why?

`k8s-harness` is for you if:

- You have apps that run on Kubernetes in production (GKE, EKS, AKS, Rancher, etc.), but
- you don't want to create (and pay for) Kubernetes clusters yourself, and
- you want a prod-like Kubernetes experience on your laptop without the hassles, and
- you just want to run your tests in a clean cluster every time.

`k8s-harness` is probably not for you if:

- You want to learn how Kubernetes works under the hood (check out Hightower's
  [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
  for that), or
- you want to run long-lived clusters on your laptop that you manage.

## How it works

[[ _insert k8s-harness flow diagram when ready_ ]]

`k8s-harness` is simple:

1. Run `k8s-harness`.
2. `k8s-harness` will look for a `.k8sharness` file in the root of your repository,
3. Once found, it will create a two-node [k3s](https://github.com/rancher/k3s) cluster
   on your machine with [Vagrant](https://vagrantup.com) and [Ansible](https://ansible.io),
4. `k8s-harness` will also provision a local insecure Docker registry into which you can push
   your app's Docker images,
4. `k8s-harness` will run your tests as defined by `.k8sharness` in a Bash subshell,
5. `k8s-harness` destroys the cluster (unless you keep it up with `--disable-teardown`).

(If you're interested in the nitty-gritty of how `k8s-harness` works, check out
[its tests](https://github.com/carlosonunez/k8s-harness/blob/master/tests) for the details.)

## Installing

- `gem install k8s-harness` if you're installing this standalone, or
- Include `k8s-harness` into your app's `Gemfile` if you're building a Ruby or Rails app.

## Options

* See [`.k8sharness.example`](https://github.com/carlosonunez/k8s-harness/blob/master/.k8sharness.example)
  for documentation on how to configure your `.k8sharness` file.
* Run `k8s-harness --help` to learn how to configure `k8s-harness` to your liking.
