To view the failed jobs queue you can go to: https://pdc-describe-prod.princeton.edu/describe/sidekiq/morgue

If there are jobs in the "dead" queue the work-around to retry these jobs is as follow:

* Connect to the VPN
* From your machine, run the capistrano task to launch the Sidekiq console from your machine. This will open two tabs on your browser, once for each server where Sidekiq is running:
```
cap production sidekiq:console
```

* Go to the first tab that Capistrano opened (e.g. http://localhost:nnnn/describe/sidekiq/morgue) and click the "retry all" button at the bottom of the page. The jobs usually succeed when retried. (**Be careful the "delete all" button is next to the "retry all" button, don't click it**).

  * After the retry you'll get an error message with something related to an SSL certificate. This is because we don't have a certificate on localhost. Remove the https from the URL to go back to the original page, you should see no "dead" jobs anymore.

* Go to the second tab that Capistrano opened (e.g. http://localhost:xxxx/describe/sidekiq/morgue) and do the same.

It is important that you access the Sidekiq interface through the tabs that the Capistrano task opened because those tabs point directly to each of the individual servers. If you go through the load balancer the retry does not work.
