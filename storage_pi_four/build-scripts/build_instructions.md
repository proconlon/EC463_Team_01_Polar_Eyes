


When you're just editing your application code (like `worker_triage.sh` or `mock_event.sh`), **do not run the build script at all.**

Instead, `rsync` your changes directly to the *running Pi* over SSH/Tailscale.

1.  Boot the Pi with your last-built image. Make sure it's on Tailscale.

2.  Edit your code on your Fedora laptop.

3.  From your laptop's terminal, run this `rsync` command to sync *only* your project files (this takes \< 1 second):

    ```bash
    rsync -av --delete ./storage_pi_four/ dev@<PI_TAILSCALE_IP>:/opt/polar-eyes/storage_pi_four/
    ```

    *(`dev@<PI_TAILSCALE_IP>` is the SSH address for your Pi).*

4.  SSH into the Pi (`ssh dev@<PI_TAILSCALE_IP>`) and test your script.