# ImmuneML Galaxy Playbook

Deploy and configure an ImmuneML-enabled Galaxy instance with Ansible.

This repository contains:
- `immuneml.yml`: the main orchestrator playbook
- `group_vars/galaxyservers.yml`: deployment configuration and helper variables
- `roles/galaxy_deployment`: baseline Galaxy deployment role (used when needed)

## What `immuneml.yml` does

The playbook runs in 4 stages:

1. **Baseline health check**
   - Checks Galaxy directories, config, service unit, service state, API endpoint, and PostgreSQL connection config.
   - Sets facts such as `galaxy_needs_baseline_attention`.

2. **Conditional Galaxy baseline deployment**
   - Runs the `galaxy_deployment` role only when Galaxy is missing or unhealthy.

3. **ImmuneML runtime strategy configuration**
   - Enforces `immuneml_runtime_strategy: conda`.
   - Creates/updates `dependency_resolvers_conf.xml` with Conda channels:
     - `bioconda`
     - `conda-forge`
     - `defaults`
   - Wires resolver config into Galaxy config.

4. **ImmuneML tool + UX registration**
   - Clones and installs ImmuneML Galaxy wrappers.
   - Pins `setuptools` requirement in wrappers (`immuneml_setuptools_version`, currently `80.9.0`).
   - Registers ImmuneML tool sections in `tool_conf.xml`.
   - Registers `yaml`, `yml`, and ImmuneML receptor datatypes in `datatypes_conf.xml`.
   - Installs custom ImmuneML welcome/static assets and sets `welcome_url`.
   - Restarts Galaxy (and nginx), then performs API health checks.

## Main configuration (`group_vars/galaxyservers.yml`)

Update these before deployment:

- **Target VM**
  - `galaxy.host_ip`: inventory host/IP alias
  - `galaxy.ssh_user`: SSH user 

- **Galaxy source**
  - `galaxy_repo`: `https://github.com/galaxyproject/galaxy.git`
  - `galaxy_commit_id`: `release_26.0`
  - `galaxy_force_checkout`: `true`

- **Security and admin**
  - `galaxy_admin_email`: set to your real admin email
  - `galaxy_database_password`: replace `CHANGE_ME_STRONG_PASSWORD`

- **HTTPS**
  - `galaxy_enable_https`: `true`
  - `galaxy_https_mode`: `selfsigned`
  - `galaxy_server_name`: `galaxy.local`
  - `galaxy_https_redirect`: `false`

- **ImmuneML runtime**
  - `immuneml_runtime_strategy`: `conda`
  - `immuneml_cli_runtime_enabled`: `false`

- **ImmuneML wrappers repo**
  - `immuneml_tools_repo_url`: `https://github.com/uio-bmi/immuneml_tools.git`
  - `immuneml_tools_version`: `main`
  - `immuneml_tools_source_dir`: `/srv/galaxy/immuneml_tools_source`
  - `immuneml_tools_force_refresh`: `true`

- **ImmuneML welcome/static assets repo**
  - `immuneml_welcome_repo_url`: `https://github.com/yehiafarag/immuneml-galaxy-playbook.git`
  - `immuneml_welcome_repo_version`: `main`
  - `immuneml_welcome_source_dir`: `/srv/galaxy/immuneml_welcome_source`
  - `immuneml_welcome_folder`: `files`
  - `immuneml_welcome_html`: `welcome_immuneml.html`
  - `immuneml_welcome_force_refresh`: `true`

The same file also defines derived helper variables (paths, runtime user/group, resolver paths, health-check URLs) used throughout `immuneml.yml`.

## Quick run

1. Update host definitions in `hosts` (or copy from `hosts.sample`).
2. Edit `group_vars/galaxyservers.yml` with your environment values.
3. Run the playbook from repository root:

```bash
ansible-playbook -i hosts immuneml.yml
```

## Notes

- The playbook is designed to avoid direct edits to Galaxy core source.
- Wrapper, datatype, and welcome-page integration are managed in Galaxy config files.
- If Galaxy is already healthy, baseline deployment is skipped automatically.
