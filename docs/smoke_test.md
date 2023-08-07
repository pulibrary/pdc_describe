# Performing a manual smoke test of the system

As indicated in [The origin of Smoke Testing and the confusion it can cause](https://www.thoughtworks.com/en-us/insights/blog/origin-smoke-testing-and-confusion-it-can-cause) a smoke test can mean different things to different people. For our purposes a smoke test is:

* A manual processs that tests basic functionality of PDC Describe
* It is one of the first, if not the first test after deployment to Staging or Production
* It's goal is to make sure the deployed version works well enough to be released and does not have show-stopper bugs on the basic functionality

## Steps

After deploying PDC Describe launch a new browser window in incognito mode and

* Go to https://pdc-describe-staging.princeton.edu/describe/ (for staging) or https://pdc-describe-prod.princeton.edu/describe/ for production
* Make sure you can login with your Princeton credentials
* You should see the home page once logged in

Once you are on the *home page*
* Go the dashboard and make sure a list of datasets is displayed

From the *dashboard*
* Click the "Submit New" button and create a new dataset
* Go through the wizard and make sure you can submit a new dataset and a couple of sample files all the way. No need to test all the fields and variations, but we want to make sure the most basic process works end to end

From the *dashboard*
* Click on the dataset that you just created and make sure the information is displayed correctly
* Click on edit, make a small change, and save it
