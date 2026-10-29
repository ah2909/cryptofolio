# Production deployment

The workflow is `push to main → build/publish GHCR images → deploy through Dokploy → check public health`.

Build, dependency-audit, and image-scan commands run directly in `.github/workflows/deploy.yml` on GitHub-hosted runners. Each candidate is loaded locally, audited and scanned, then pushed without rebuilding. A failed audit or scan prevents publication of that candidate and prevents the deploy job from running. JSON audit/scan reports are retained even on failure. Custom smoke tests are not part of deployment.

## Runtime security upgrades

The backend uses digest-pinned PHP 8.2.35 on Debian 13, with a build-time minimum for Debian's patched Brotli library and upload progress disabled before request parsing. Composer dependencies use the same PHP/extensions as runtime. The backend dependency lock now uses Laravel 12.70.2; commit the backend submodule changes before relying on remote builds. PHP 8.2 still needs migration before its December 2026 end of support; Laravel 12 is the supported bridge to the planned Laravel 13 upgrade.

Auth and websocket use digest-pinned Node 24.22.2 on Alpine 3.24 and run production as UID 1000. npm 12.2.1's bundled Undici is patched to 6.29.1. Their dependency locks contain the audited updates, including bcrypt 6 and websocket's ws 8.22 pin. Commit changes in both service repositories before remote builds.

Auth signing-key bind mounts must be readable by UID 1000 or its configured group while keeping private keys restricted. Deployment audits and image scans do not validate key permissions or application behavior; check those mounts and login behavior separately before deploying.

The deployment workflow runs `composer audit --locked --no-dev` for backend candidates and `npm audit --omit=dev --audit-level=high` for Node candidates. Every service candidate receives a final-image HIGH/CRITICAL scan. The backend Dockerfile still enforces the patched Brotli minimum and Composer platform requirements during builds. Backend tests remain available manually through the Dockerfile test target. No temporary application, database, or Redis containers are started by these deployment gates.

The current Debian image still has additional HIGH/CRITICAL scan findings without available packaged fixes. The gate intentionally rejects that backend candidate; passing PHP2Shell/Brotli checks and application tests does not override the image scan. Do not weaken the threshold or restore unsupported runtimes to make deployment pass. Review the retained report and vendor fixes before release. Development does not require backups or retention of previous images for this upgrade.

## Which services deploy

| Trigger | Images built and updated |
| --- | --- |
| Push to a service repository's `main` | Only that service, via its parent notification workflow. Other production image references stay unchanged. |
| Push to parent `main` updating submodule pointers or service Docker files | Only services whose paths changed. Shared `.dockerignore` or `.gitmodules` changes select all. Docs/workflow-only changes do not deploy. |
| Parent Actions → Production → Run workflow → `service: all` | Rebuild and redeploy all five services. Use this for the first deployment. |
| Parent Actions → Production → Run workflow → a service name | Rebuild and redeploy only that service. |

Selected services are fetched from the current `main` heads of their configured repositories. Parent gitlinks select affected services; they do not pin production source in this flow. A service notification is accepted only for its expected repository and current `main` SHA; superseded notifications are skipped. The release artifact records the actual selected module commits. Update parent gitlinks separately if you want the parent checkout to match production.

Dokploy still runs Compose for the project, while unchanged image references are preserved. Compose may start dependencies or recreate a migration container when the backend image changes; selecting one service does not promise that every other container stays untouched.

### Connect submodule pushes

1. Commit `.github/workflows/deploy.yml` in backend/websocket and `.github/workflows/notify-production.yml` in auth/analyzer/alert to their own repositories. Backend/websocket's old SSH deploy workflows have been replaced locally.
2. Create a fine-grained PAT scoped only to parent repository `ah2909/cryptofolio`, with **Contents: write**, or provision an equivalent GitHub App installation token. Set it as `PARENT_DEPLOY_TOKEN` in each of the five service repositories. Their built-in `GITHUB_TOKEN` cannot dispatch to another repository. Never paste the token into chat or commit it.
3. Commit the parent workflow to its default `main` branch; `repository_dispatch` requires the receiving workflow on the default branch. Finish the existing Dokploy/GitHub production configuration, then run `service: all` once before relying on selective deploys.
4. Future service `main` pushes send a `service-push` notification to the parent. No parent commit is required for that notification. Notifications only trigger GitHub Actions; no workflow was sent or deployment performed during implementation.

Production concurrency uses `queue: max` with active-run cancellation disabled, so pushes for different services wait instead of replacing each other's pending runs. GitHub permits up to 100 queued runs; monitor failed notifications/queue overflow. [GitHub dispatch API](https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event), [workflow event behavior](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#repository_dispatch), [queue configuration](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency).

## Before the first deployment

1. Confirm the homelab is x86-64: the workflow builds `linux/amd64` images. Commit/push the notification workflows and intended changes in each service submodule. Private submodules need separately scoped read access; the workflow currently assumes they are public.
2. Back up existing databases/uploads. The production template creates named volumes and does not import development bind-mounted data. Restore existing data and reconcile migration history before deployment if needed.
3. Create a Dokploy **Raw / Docker Compose** service. Paste `compose.production.yml` and save without deploying the placeholder images.
4. Disable Git push auto-deploy, webhooks, scheduled deployments, randomization, and isolated deployment/volumes. Avoid manual deployments while this workflow runs.
5. In Dokploy Advanced, preserve the project name and Compose file arguments from the default command and use:

   ```text
   compose -p <same-app-name> -f <same-compose-path> up -d --wait --wait-timeout 600
   ```

   Dokploy adds the leading `docker`. Use a Compose version supporting `--wait` and successful one-shot dependencies. Do not use fresh volumes, `down -v`, volume renewal, or pruning.
6. Set the application environment in Dokploy using the table below. Create persistent File Mounts for `../files/id_rsa_priv.pem` and `../files/id_rsa_pub.pem`; the auth service mounts these as its existing RSA key pair. Keep the same keys and Laravel `APP_KEY` across releases.
7. Configure GHCR pull access in Dokploy: either a dedicated classic PAT with `read:packages` and access to all five packages, or explicitly public packages. Public repository visibility does not make new packages public. If using public packages, pause the first deployment with an optional GitHub environment reviewer until package visibility is configured. Alternatively, rerun only the deploy job after fixing access.
8. Configure Dokploy domains and tunnel routing: backend port 80, auth port 8086, websocket port 3003, alert API port 4000 if public. Keep the analyzer internal. Ensure Traefik reaches `dokploy-network`, and cloudflared preserves the incoming Host header.
9. Protect the Dokploy dashboard with human Cloudflare Access. Add a **Service Auth** policy accepting the deployment service token, preferably restricted to `/api/compose.one`, `/api/compose.update`, `/api/compose.deploy`, and `/api/deployment.allByCompose`. Preserve human access to dashboard API calls. Make backend `/up` publicly accessible and bypass caching/interactive Access challenges for this health path.
10. Create a GitHub `dokploy` environment restricted to `main`, and configure the following secrets and variables. Push the workflow and deployment files to parent `main`, then run the workflow manually with `service: all` when setup is ready.

### GitHub configuration

| Kind | Names |
| --- | --- |
| Secrets | `DOKPLOY_API_KEY`, `CF_ACCESS_CLIENT_ID`, `CF_ACCESS_CLIENT_SECRET` |
| Variables | `DOKPLOY_URL`, `DOKPLOY_COMPOSE_ID`, `APP_HEALTH_URL` |

Use the HTTPS Dokploy origin for `DOKPLOY_URL`, without `/api`, and the public Laravel `/up` URL for `APP_HEALTH_URL`. The Dokploy key must allow reading/updating the intended Compose service and creating/reading its deployments. Never paste credentials into chat, commit them, or pass them as build arguments.

### Dokploy application environment

| Variables | Purpose |
| --- | --- |
| `APP_KEY` | Stable Laravel encryption key. |
| `BACKEND_URL`, `FRONTEND_URL`, `COOKIE_DOMAIN` | Public origins and auth cookie domain. |
| `BACKEND_DATABASE`, `BACKEND_USERNAME`, `BACKEND_PASSWORD`, `BACKEND_ROOT_PASSWORD` | Backend database settings. |
| `AUTH_DATABASE`, `AUTH_USERNAME`, `AUTH_PASSWORD`, `AUTH_ROOT_PASSWORD` | Auth database settings. |
| `REDIS_PASSWORD` | Long random alphanumeric value; existing Go code embeds it into a URL without escaping. |
| `ALERT_MYSQL_DSN` | Go backend DB connection, e.g. `user:password@tcp(backend-db:3306)/portfolio?parseTime=true`; supply real credentials securely. |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | OAuth credentials; configure the existing callback routes for the public auth hostname in Google. |
| `GEMINI_API_KEY`, `GEMINI_MODEL` | Analyzer credentials/model. |
| `COINGECKO_API_KEY`, `COINGECKO_PRO` | Market data credentials; Pro defaults to false. |
| `BACKEND_IMAGE`, `AUTH_SERVICE_IMAGE`, `WEBSOCKET_IMAGE`, `PORTFOLIO_ANALYZER_IMAGE`, `CRYPTO_ALERT_ENGINE_IMAGE` | Initial placeholder image values needed to save the template. Use the intended image names with `:bootstrap`; do not deploy them. The workflow replaces image lines with published digests. |

Only explicitly referenced environment values enter each container. Add any additional application-specific values from service `.env.example` files directly to Raw Compose. Those additions are preserved. Database initialization credentials only apply to empty volumes; changing an environment value does not rotate an existing database password. Database traffic stays on a private Docker network; add certificate configuration if you require transport TLS within the homelab.

## What deployment does

- Builds selected images from the root context using `docker/<service>/Dockerfile`, target `production`. Image names are lowercase `ghcr.io/<owner>/<repository>/<service>:sha-<module-commit>-run-<run-id>-<attempt>`, so manual rebuilds and repeated events never overwrite a previous tag. There is no frontend image in this repository.
- Uses `GITHUB_TOKEN`; only publishing receives `packages: write`. Existing run tags are not intentionally overwritten. If publishing is partial, fix the failure and rerun the workflow; its new run attempt gets fresh immutable tags. If publishing completed, rerun only deploy using its artifact.
- Records selected image digests and module commits in the `production-release` artifact, and all five deployed image references in `production-deployment-record`. Keep known-good manifests and their registry images for rollback; artifacts are retained for 90 days.
- Authenticates to Dokploy with Cloudflare service-token headers plus the separate `x-api-key` header. Requests never follow redirects. Response bodies stay in private temporary files and are never printed.
- Reads Raw Compose, replaces only the selected application image lines, preserving all other lines and the backend migration alias. Keep the supplied two-space service layout and `&backend-image` anchor. Production environment values are never written. It re-reads configuration before triggering deployment.
- Sends exactly one deployment trigger with `freshVolumes: false`. Only GET requests retry. An ambiguous mutation response fails and must be inspected in Dokploy before retrying.
- Waits up to 15 minutes for a new deployment record with this run's unique title. Old successes and unrelated deployments do not count. Failure, cancellation, unknown status, or timeout fail the workflow.
- Confirms the intended image configuration remains saved, then waits up to 3 minutes for public HTTP 200 health. GitHub concurrency prevents overlapping runs without cancelling an active deployment. Independent/manual writers remain outside that lock.

The original application images have no public commit-version endpoint. This workflow verifies the configured image digests, correlated Dokploy completion, and public health; it cannot independently prove the commit serving the public request. There is no `/release.json` check or image modification.

The `migrate` service runs Laravel migrations before backend/alert startup. Auth retains its existing Sequelize startup synchronization; the Go service retains GORM migration behavior. Database and upload volumes persist between releases. Configure and test backups; image rollback does not reverse schema changes. If publicly serving Laravel uploads, configure the storage symlink/startup handling in Dokploy as required by the existing application.

## Image build validation

The Go Dockerfile copies only src/crypto-alert-engine into /app and builds ./cmd from that module root. Production and development images were built locally for linux/amd64. Container checks confirmed the executable and non-root user in production, the module, Air configuration and source layout in development, and exclusion of .env files in both images. The application was not started against MariaDB or Redis. The other four application image builds and the live deployment have not been validated.

## Troubleshooting and rollback

To inspect connectivity and saved Compose settings without building images or deploying, run the Production workflow manually with check_settings enabled. It makes only a read-only compose.one request and prints selected settings and command checks; environment values and credentials remain private. Leave check_settings disabled for deployment.

| Failure | Check |
| --- | --- |
| Checkout/build/publish failure | Remote submodule commits/access, original Dockerfile build paths, dependency availability, disk space, package permissions. |
| Existing run tag | Rerun only deploy after completed publication, or rerun the workflow to create fresh attempt tags. |
| Dokploy 401/403/redirect | Service Auth token/policy paths, Dokploy key permissions, correct HTTPS origin. Do not print headers or authenticated response bodies. |
| Configuration check fails | Raw Docker Compose, stable project/volume identities, safe `--wait` command, original service/image layout. |
| Pull failure | GHCR package access/visibility and read-only registry credentials on the actual deployment server. |
| Migration/container health failure | Dokploy logs, DB/schema history, persistent keys, runtime configuration. Never delete volumes to resolve it. |
| Deployment timeout/ambiguous request | Inspect the uniquely titled deployment in Dokploy. A timeout does not cancel its server-side work. Wait or resolve it before another trigger. |
| Public health failure | Traefik backend port 80, tunnel origin/Host header, DNS, cache bypass and public `/up` access. |

To roll back, wait until no deployment is active, back up current data, and check database compatibility. In Dokploy Raw Compose, replace only the five image references with digests from an archived known-good full `deployedImages` record (or the selected entries for a one-service rollback), keeping `migrate` on the backend anchor. Deploy through Dokploy using the same safe command, check completion and public `/up`, then record the rollback and repair/revert the source commits before the next push.

Do not run automatic database rollback. Laravel, Sequelize and GORM schema changes can require a forward fix or separately planned backup restoration.

## Validation and references

Local checks covered service selection, stale/invalid notifications, selective/full updates, first-deployment protection, failure handling, and preservation of secrets/untouched image references using mocked Git/Dokploy responses. No production publication or deployment was performed. Actionlint 1.7.12 passed with only its obsolete `queue` syntax warning excluded; `queue: max` is supported in the current official GitHub documentation linked above. Validate workflow syntax with a current actionlint version, and production Compose with `docker compose --env-file <dummy-values.env> -f compose.production.yml config --quiet`. Never print a resolved production configuration containing credentials.

Official references: [Dokploy Compose API](https://docs.dokploy.com/docs/api/compose), [deployment status API](https://docs.dokploy.com/docs/api/deployment), [Dokploy Compose configuration](https://docs.dokploy.com/docs/core/docker-compose), [Cloudflare service tokens](https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/), and [GHCR authentication/visibility](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry). Check API compatibility against your installed Dokploy version. Action SHAs were verified against the official GitHub repositories during implementation.
