
#Check if we have any SC, PVC, or PV 
kubectl get StorageClass
kubectl get PersistentVolumeClaim
kubectl get PersistentVolume

#Install helm: Kubernetes package Manager (https://helm.sh/)
        #Install gudie: https://helm.sh/docs/intro/install/
        #Getting started: https://helm.sh/docs/intro/quickstart/ 

#Install "nfs-subdir-external-provisioner" dynamic provisioner therough "helm". 
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=192.168.0.14 \
    --set nfs.path=/export/volumes/dynamic

    #To uninstall "nfs-subdir-external-provisioner"
    #helm delete nfs-subdir-external-provisioner

#Check what is installed as part of above dynamic provisioner
kubectl get deployments
kubectl get pods

#Check again if we have any any SC, PVC, or PV: 
kubectl get StorageClass    

#Make "nfs-client" class as deafult storage class 
kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    #To remove "nfs-client" as the default 
    #kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

#Create a new PVC
kubectl apply -f test-dynamic-claim.yaml
    #Verify 
    kubectl get PersistentVolumeClaim
    kubectl get PersistentVolume
    kubectl describe PersistentVolumeClaim pvc-nfs-dynamic-data 


#Let's create some content on our storage server
ssh gary@ubuntuvm
    ls /export/volumes/dynamic
    export VOLUME=$(ls /export/volumes/dynamic | awk '{ print $1}' | grep default)
    sudo bash -c 'echo "Hello from our Dyanic NFS mount!" > /export/volumes/dynamic/"'"$VOLUME"'"/demo.html' 
    cat /export/volumes/dynamic/$VOLUME/demo.html
exit

#Deploy or nginx app again but this time leverage dynamic storage allocation
kubectl apply -f nginx-dynamic-storage.yaml
#Verify
kubectl describe PersistentVolumeClaim pvc-nfs-dynamic-data 

#Get the ServiceIP and POD name:
SERVICEIP=$(kubectl get service | grep nginx-service | awk '{ print $3 }')
POD_NAME=$(kubectl get pods -no-headers -n default | awk '{ print $1}' | grep nginx-deployment)

#Verify that that the vlume is loaded into the POD
kubectl describe pod $POD_NAME

#We can also verify that "demo.html" file shows up under "usr/share/nginx/html/web-app" folder 
kubectl exec -it $POD_NAME -- /bin/bash
    ls /usr/share/nginx/html/web-app
exit

#Let's access that application to see our application data...
curl http://$SERVICEIP/web-app/demo.html

#Delete the deployment
kubectl delete -f nginx-dynamic-storage.yaml
    kubectl get PersistentVolumeClaim
    kubectl get PersistentVolume

#Delete the PVC and examine what happens to PV
kubectl delete -f test-dynamic-claim.yaml    
    kubectl get PersistentVolume


#Clean up
kubectl delete -f nginx-dynamic-storage.yaml
kubectl delete -f test-dynamic-claim.yaml
kubectl delete -f nginx-dynamic-storage.yaml
