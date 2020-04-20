Manual steps
==
 * Nexus -> S3
 * Jenkins Config - GitHub Server
 * Jenkins - create GitHub organization, filter on PROJECTPREFIX-*, autobuild "master"
 * Jenkins add plugins:
      List is here templates/jenkins.yaml.tmpl -> installPlugins.
      If you need something else or update for existed -> provide PR. 

Adding CVE (WIP)
==
```bash
aws-vault exec `cat .aws-profile` -- jx ns jx
aws-vault exec `cat .aws-profile` -- jx create addon anchore
```

Staging Env creation steps (semi-automatic)
==
First we fetch the template
```bash
mkdir my_infra && cd my_infra
git init
git remote add origin https://github.com/GITHUB_ORG/PROJECT-infra # Change to real application repo
git remote add upstream https://github.com/jenkins-x/default-environment-charts
git fetch --all
git reset --hard remotes/upstream/master
```

Then replace template vars and push new version
```bash
export DOMAIN=PROJECT.example.com

sed -i "/expose:/a\ \ config:\n\ \ \ \ tlsacme: \"true\"\n\ \ \ \ domain: $DOMAIN" env/values.yaml

grep -rl --exclude-dir=.git 'change-me' --null | xargs -0 sed -i -e "s/change-me/jx-staging/g"
git commit -a -m "fix: init as jx-staging at $DOMAIN"
git push -f origin master

```

And register new environment in JX (say "no" to creating new repo and specify existing)
```bash
aws-vault exec `cat .aws-profile` -- jx ns jx
# optional: aws-vault exec --assume-role-ttl=1h `cat .aws-profile` -- jx create jenkins token
aws-vault exec `cat .aws-profile` -- jx create environment -n staging -l Staging -s jx-staging
```

Then remove folder from Jenkins if you using GitHub organization with auto-discover.

