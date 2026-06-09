
# Immune-ml Galaxy Playbook

Deploy ImmuneML on Galaxy using a clean, modular Ansible architecture.

This project provides an independent integration layer on top of a Galaxy playbook, ensuring:
- clear separation between infrastructure and tools
- reproducible deployments
- safe Galaxy upgrades
  This repository contains the Ansible playbook and role for deploying ImmuneML
  (https://github.com/uio-bmi/immuneML) as a Galaxy tool.

The design follows a production-grade approach:
- Galaxy is deployed separately using a dedicated playbook
- ImmuneML is installed as an independent layer
- No direct modifications are made to Galaxy core or upstream roles