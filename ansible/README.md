### Pre-requisites
- [Install ansible to your local machine](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html).
- Add your user into each of the hosts found in the hosts file `ansible/hosts`

### Setup
- Copy the hosts file into your machine hosts
```
cp hosts /etc/ansible/hosts
```

```
# To setup a new clinic
# variables

# host - the target host we want to deploy to ie. aws1, aws2
# name
# slug
# subtext
# port_identifier - numbers on port (both NN). ie 67
#   - oscar port will be 8673
#   - mysql port will be 3672
# (optional) province - `ontario` or `bc` for now, defaults to bc
# (optional) website - Your clinic website, defaults to https://slug.openosp.ca
# (optional) docker_image - defaults to openosp/open-osp:release 

ansible-playbook new-clinic.yml --extra-vars "host=HOST name='CLINIC_NAME' slug=CLINIC_SLUG subtext='CLINIC SUBTEXT' port_identifier=67" -become -become_user=jenkins -K
```