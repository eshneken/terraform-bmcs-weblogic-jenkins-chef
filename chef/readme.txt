Whenever recipes are updated, you need to do two things:

1) push changes to GitHub
2) push changes to Chef Repo (knife upload cookbooks/bmcs_servers)

Number 2 is important since the Chef server is the single-source-of-truth for bootstrapping of servers.
