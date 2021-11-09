#!/bin/bash -e 

kubectl apply -f test-pod-emptydir.yaml
kubectl get pods -o wide
    #test-pod-deployment-76df6849d4-82m4w

POD=$(kubectl get pods -no-headers -n default | awk '{ print $1}' | grep test-pod)

kubectl exec -it $POD -- sh
    cd /cache
    echo "Hello from emptyDir storage!" > test.txt
    cat test.txt
exit

#Simulate a crash 
sudo reboot

#Verify that a new POD will be created aftre the crash
kubectl get pods -o wide

#Save the new POD name and ssh to it to verify the file created on the mount survied the crash
POD=$(kubectl get pods -no-headers -n default | awk '{ print $1}' | grep test-pod)
kubectl exec -it $POD -- sh
    cd /cache    
    cat test.txt
exit


#Cleanup
kubectl delete -f test-pod-emptydir.yaml














#****************************************************************************************************************************************
export POD1;
export POD2;

PODS=$(kubectl get pods -no-headers -n default | awk '{ print $1}' | grep test-pod)

i=0;
for p in $PODS; do    
    if (( i==0 ))
        then    
            POD1=$p            
            ((i+=1))   
    else
        POD2=$p         
    fi
done

echo $POD1
echo $POD2

kubectl get PersistentVolume

kubectl exec -it $POD1 -- sh
    cd /cache
    echo "Hello World" > test.txt
    cat test.txt
exit

kubectl exec -it $POD2 -- sh
    cd /cache
    ls    
exit

kubectl delete -f test-pod-emptydir.yaml
