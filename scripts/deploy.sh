echo "deploy start"
git config core.sshCommand 'ssh -i ~/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
git fetch --unshallow
git pull origin master
echo "DEPLOY TO $DEPLOY_HOST"
git remote add deploy $DEPLOY_HOST
git push -f deploy master
