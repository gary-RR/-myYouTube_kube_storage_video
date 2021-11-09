#Log into a Kubernetes node
ssh gary@192.168.0.22

#NFS Server setup
#Log into your storage vm
ssh gary@ubuntuvm

    #Install NFS Server (More info: https://ubuntu.com/server/docs/service-nfs)
    #Install NFS Server and create the directory for our exports
    sudo apt install nfs-kernel-server -y
   
    sudo mkdir -p /export/volumes
    sudo mkdir -p /export/volumes/static
    sudo mkdir -p /export/volumes/dynamic

    #Configure our NFS Export in /etc/export for /export/volumes. Using no_root_squash and no_subtree_check to 
    #allow applications to mount subdirectories of the export directly.
    sudo bash -c 'echo "/export/volumes  *(rw,no_root_squash,no_subtree_check)" > /etc/exports'
    cat /etc/exports
    sudo systemctl restart nfs-kernel-server.service
exit


#On each Node in your cluster...install the NFS client.
sudo apt install nfs-common -y

#Test out basic NFS access before moving on.
sudo mount -t nfs4 ubuntuvm:/export/volumes /mnt/
mount | grep nfs
sudo umount /mnt


#Static Provisioning Persistent Volumes
#Create a PV with the read/write many and retain as the reclaim policy
kubectl apply -f nfs-static-pv.yaml
    
#Review the created resources, Status, Access Mode and Reclaim policy is set to Reclaim rather than Delete. 
kubectl get PersistentVolume pv-nfs-static-data

#Create a PVC on that PV
kubectl apply -f nfs-static-pvc.yaml
      
#Check the status, now it's Bound due to the PVC on the PV. See the claim...
kubectl get PersistentVolume

#Check the status, Bound.
#We defined the PVC it statically provisioned the PV...but it's not mounted yet.
kubectl get PersistentVolumeClaim pvc-nfs-static-data
    
kubectl describe PersistentVolumeClaim pvc-nfs-static-data

#Let's create some content on our storage server
ssh gary@ubuntuvm
    sudo bash -c 'echo "Hello from our static NFS mount!" > /export/volumes/static/demo.html'
    cat /export/volumes/static/demo.html
exit


#Let's create a Pod (in a Deployment and add a Service) with a PVC on pvc-nfs-data
kubectl apply -f nginx.yaml
kubectl get service nginx-service
SERVICEIP=$(kubectl get service | grep nginx-service | awk '{ print $3 }')

#Check to see if our pods are Running before proceeding
kubectl get pods
POD_NAME=$(kubectl get pods -no-headers -n default | awk '{ print $1}' | grep nginx-deployment)

#Let's access that application to see our application data...
curl http://$SERVICEIP/web-app/demo.html


#Check the Mounted By output for which Pod(s) are accessing this storage
kubectl describe PersistentVolumeClaim pvc-nfs-static-data
 

#If we go 'inside' the Pod/Container, let's look at where the PV is mounted
kubectl exec -it $POD_NAME -- /bin/bash
    ls /usr/share/nginx/html/web-app
    more /usr/share/nginx/html/web-app/demo.html
exit


#What node is this pod on?
kubectl get pods -o wide

#Let's log into that node and look at the mounted volumes...it's the kubelets job to make the device/mount available.
#sshuser@nodex
    mount | grep nfs
    sudo ls #location obtained from "mount | grep nfs"
#exit


#Let's delete the pod and see if we still have access to our data in our PV...
kubectl delete pods $POD_NAME

#We get a new pod...but is our app data still there???
kubectl get pods

#Let's access that application to see our application data...yes!
curl http://$SERVICEIP/web-app/demo.html

#Controlling PV access with Access Modes and persistentVolumeReclaimPolicy
#scale up the deployment to 4 replicas
kubectl scale deployment nginx-deployment --replicas=4


#Now let's look at who's attached to the pvc, all 4 Pods
#Our AccessMode for this PV and PVC is RWX ReadWriteMany
kubectl describe PersistentVolumeClaim 


#Now when we access our application we're getting load balanced across all the pods hitting the same PV data
curl http://$SERVICEIP/web-app/demo.html


#Let's delete our deployment
kubectl delete deployment nginx-deployment


#Check status, still bound on the PV...why is that...
kubectl get PersistentVolume 


#Because the PVC still exists...
kubectl get PersistentVolumeClaim

#Can re-use the same PVC and PV from a Pod definition...yes! Because I didn't delete the PVC.
kubectl apply -f nginx.yaml

#Our app is up and running
kubectl get pods 


#But if I delete the deployment
kubectl delete deployment nginx-deployment

#AND delete the PersistentVolumeClaim
kubectl delete PersistentVolumeClaim pvc-nfs-static-data

#My status is now Released...which means no one can claim this PV
kubectl get PersistentVolume


#But let's try to use it and see what happend, recreate the PVC for this PV
kubectl apply -f nfs-static-pvc.yaml


#Then try to use the PVC/PV in a Pod definition
kubectl apply -f nginx.yaml


#My pod creation is Pending
kubectl get pods


#As is my PVC Status...Pending...because that PV is released and our Reclaim Policy is Retain
kubectl get PersistentVolumeClaim
kubectl get PersistentVolume


#Need to delete the PV if we want to 'reuse' that exact PV...to 're-create' the PV
kubectl delete deployment nginx-deployment
kubectl delete pvc pvc-nfs-static-data   
kubectl delete pv pv-nfs-static-data
    
#If we recreate the PV, PVC, and the pods. we'll be able to re-deploy. 
#The clean up of the data is defined by the reclaim policy. (Delete will clean up for you, useful in dynamic provisioning scenarios)
#But in this case, since it's NFS, we have to clean it up and remove the files
#Nothing will prevent a user from getting this acess to this data, so it's imperitive to clean up. 
kubectl apply -f nfs-static-pv.yaml
kubectl apply -f nfs-static-pvc.yaml
kubectl apply -f nginx.yaml
kubectl get pods 


#Clean up
kubectl delete -f nginx.yaml
kubectl delete pvc pvc-nfs-static-data
kubectl delete pv pv-nfs-static-data









































