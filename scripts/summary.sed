sed \
-e 's/iris-demo-train-1086554222/train  /' \
-e 's/iris-demo-model-validation-4150168498/validat/' \
-e 's/iris-demo-semantic-versioning-3276471007/semanti/' \
-e 's/iris-demo-monitor-105816203/monitor1/' \
-e 's/iris-demo-kaniko-2749533263/kaniko /' \
-e 's/iris-demo-deploy-2552441111/deploy /' \
-e 's/iris-demo-monitor-2817433534/monitor2/' 


##  argo logs iris-demo -n iris-demo | ansi2txt | scripts/summary.sed | cut -c 1-80 | grep -E -v   '^(train  |semanti|validat|kaniko |deploy |monitor[1|2]):[ ]+(Downloading|Collecting|Requirement already satisfied|Selecting|Preparing|Unpacking|Setting up).*' | more | grep -v debian
