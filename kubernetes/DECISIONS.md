# Migrate ArgoCD to FluxCD
ArgoCD Is using a lot of resources and is not needed for the current setup. We can use FluxCD to manage our GitOps workflow. This will help us to reduce the resource usage and make the setup more efficient.

I'm managed to put all ArgoCD resources in my Raspberry PI and it consumes the whole NODE byt itself and does not perform well. 

On the following images, it shows the CPU consumption and Thermal thermal throttling of the Raspberry PI.
## CPU
![CPU](resources/images/argocd-resources-01.png)
## Thermal Throttling
![THERMAL](resources/images/argocd-resources-02.png)

I currently run my raspberry PI with passive cooling and I don't want to add noise through extra cooling for my setup.

## Solution
Migrate ArgoCD to FluxCD. This will help to reduce the resource usage and make the setup more efficient. 