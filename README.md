# Installation
  
  #### Installation to your scratch org.
  
```console
# Set the defaultdevhubusername
sfdx force:config:set defaultdevhubusername=<yourdevhubusername>
  
# Create a new scratch org if you don't already have it 
sfdx force:org:create -f config/project-scratch-def.json -a squery-org
  
# push the source code to your scractch org
sfdx force:source:push -u test-plcehsuzpvsp@example.com
  
# open your org.
sfdx force:org:open -u test-plcehsuzpvsp@example.com
```
  
  #### Installation to your non-scratch org(s).
  
```console
# Login your developer or sandbox org with the following sfdx command
sfdx force:auth:web:login --setalias my-dev-org
  
# Deploy the source code to your org
sfdx force:source:deploy -p force-app -u my-dev-org 
```
  
# Usage






