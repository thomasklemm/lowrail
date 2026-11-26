# Candidate 0.2 compare gates, evaluated on the receipts (output of scripts/noise_gate.rb)

Columns: false alarms of one compare, of the CI job (head profiled again on a flag; *any* row or the *same* row flagged twice), plant caught (one compare / CI job), and the smallest regression an action needs to be flagged in 95% of assignments (d95: median and 90th percentile over compared actions, objects per request and share of the action). Base sets are all assignments, or 120 sampled (seed 1) where there are more.

## forem: Forem, rspec spec/requests, PARALLEL_WORKERS=1, 8 + 2 planted

Processes per capture: 1. Kinds compared: request, mail. Rows: 10720, of which 9402 are identical in every run of every capture.

| Variant | Declined | One compare | CI job (any) | CI job (same row) | CI job (merged) | Plant: one / CI | Action d95 median | Action d95 p90 | Rows flagged most |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| aa1 (0.1 rule) | – | 65.48% (220/336) | 44.88% (754/1680) | 18.57% (312/1680) | 15.54% (261/1680) | 100.00% (112/112) / 100.00% (112/112) | 44 (0.36%) | 248 (1.30%) | Feeds::SourcesController#update 60, AgentSessionsController#show 38 |
| range-2 k2 | – | 64.88% (109/168) | 44.52% (374/840) | 18.33% (154/840) | 15.60% (131/840) | 100.00% (56/56) / 100.00% (56/56) | 43 (0.34%) | 237 (1.25%) | Feeds::SourcesController#update 30, AgentSessionsController#show 17 |
| range-3 k2 | – | 54.76% (92/168) | 31.43% (264/840) | 13.81% (116/840) | 12.38% (104/840) | 100.00% (56/56) / 100.00% (56/56) | 61 (0.48%) | 338 (1.82%) | Feeds::SourcesController#update 30, Admin::BillboardCampaignsController#show 15 |
| range-2 k2 share 0.5% | – | 40.48% (68/168) | 17.62% (148/840) | 8.10% (68/840) | 8.10% (68/840) | 0.00% (0/56) / 0.00% (0/56) | 77 (0.56%) | 237 (1.25%) | Feeds::SourcesController#update 30, Admin::BillboardCampaignsController#show 15 |
| env k2 | – | 82.14% (138/168) | 66.67% (560/840) | 28.10% (236/840) | 25.24% (212/840) | 100.00% (56/56) / 100.00% (56/56) | 35 (0.28%) | 132 (0.73%) | AgentSessionsController#show 45, Admin::CommentsController#show 31 |
| env k2 share 0.5% | – | 33.33% (56/168) | 13.10% (110/840) | 6.43% (54/840) | 7.14% (60/840) | 0.00% (0/56) / 0.00% (0/56) | 84 (0.61%) | 190 (0.98%) | Feeds::SourcesController#update 30, Admin::UsersController#full_delete 12 |
| pred99 k2 | – | 99.40% (167/168) | 98.81% (830/840) | 76.90% (646/840) | 94.64% (795/840) | 32.14% (18/56) / 32.14% (18/56) | 263 (2.05%) | 1618 (9.46%) | Admin::BillboardCampaignsController#show 30, Feeds::SourcesController#update 30 |
| rank k2 | – | 100.00% (168/168) | 100.00% (840/840) | 99.05% (832/840) | 100.00% (840/840) | 100.00% (56/56) / 100.00% (56/56) | 28 (0.22%) | 66 (0.41%) | AgentSessionsController#show 56, logger/log_device.rb:33 55 |
| range-2 k2 r1 | – | 100.00% (168/168) | 100.00% (840/840) | 92.14% (774/840) | 90.95% (764/840) | 100.00% (56/56) / 100.00% (56/56) | 39 (0.32%) | 167 (0.97%) | UsersController#add_org_admin 39, Admin::UsersController#full_delete 38 |
| env k2 r1 | – | 100.00% (168/168) | 100.00% (840/840) | 94.52% (794/840) | 95.12% (799/840) | 100.00% (56/56) / 100.00% (56/56) | 37 (0.29%) | 96 (0.55%) | logger/log_device.rb:33 51, Admin::UsersController#full_delete 48 |
| range-2 k3 | – | 36.43% (102/280) | 15.54% (174/1120) | 5.00% (56/1120) | 4.91% (55/1120) | 100.00% (112/112) / 100.00% (112/112) | 43 (0.34%) | 240 (1.29%) | Feeds::SourcesController#update 40, Admin::BillboardCampaignsController#show 20 |
| range-3 k3 | – | 30.00% (84/280) | 10.18% (114/1120) | 4.82% (54/1120) | 4.82% (54/1120) | 100.00% (112/112) / 100.00% (112/112) | 61 (0.48%) | 342 (1.86%) | Feeds::SourcesController#update 40, Admin::BillboardCampaignsController#show 20 |
| range-2 k3 share 0.5% | – | 25.00% (70/280) | 8.39% (94/1120) | 3.75% (42/1120) | 3.84% (43/1120) | 0.00% (0/112) / 0.00% (0/112) | 76 (0.55%) | 241 (1.29%) | Feeds::SourcesController#update 40, Admin::BillboardCampaignsController#show 20 |
| env k3 | – | 72.50% (203/280) | 51.79% (580/1120) | 11.96% (134/1120) | 9.46% (106/1120) | 100.00% (112/112) / 100.00% (112/112) | 36 (0.28%) | 135 (0.77%) | AgentSessionsController#show 53, Admin::CommentsController#show 45 |
| env k3 share 0.5% | – | 18.57% (52/280) | 6.25% (70/1120) | 4.11% (46/1120) | 4.29% (48/1120) | 0.00% (0/112) / 0.00% (0/112) | 85 (0.61%) | 191 (0.99%) | Feeds::SourcesController#update 40, Admin::UsersController#full_delete 6 |
| pred99 k3 | – | 98.57% (276/280) | 97.14% (1088/1120) | 68.57% (768/1120) | 93.57% (1048/1120) | 100.00% (112/112) / 100.00% (112/112) | 48 (0.37%) | 283 (1.63%) | Admin::FlagAppealsController#index 40, OrganizationSettingsController#request_verification 40 |
| rank k3 | – | 100.00% (280/280) | 100.00% (1120/1120) | 96.43% (1080/1120) | 100.00% (1120/1120) | 100.00% (112/112) / 100.00% (112/112) | 27 (0.22%) | 66 (0.38%) | Admin::UsersController#full_delete 70, AgentSessionsController#show 70 |
| range-2 k3 r1 | – | 100.00% (280/280) | 100.00% (1120/1120) | 75.18% (842/1120) | 74.38% (833/1120) | 100.00% (112/112) / 100.00% (112/112) | 40 (0.32%) | 176 (1.02%) | OmniauthCallbacksController#github 47, UsersController#add_org_admin 43 |
| env k3 r1 | – | 100.00% (280/280) | 100.00% (1120/1120) | 81.07% (908/1120) | 82.14% (920/1120) | 100.00% (112/112) / 100.00% (112/112) | 37 (0.29%) | 101 (0.58%) | Admin::UsersController#full_delete 63, logger/log_device.rb:33 60 |
| range-2 k3 self-check | 100.00% (56/56) | – | – | – | – | – / – | – | – |  |
| env k3 self-check | 100.00% (56/56) | – | – | – | – | – / – | – | – |  |
| range-2 k4 | – | 22.14% (62/280) | 7.38% (62/840) | 3.57% (30/840) | 3.57% (30/840) | 100.00% (140/140) / 100.00% (140/140) | 44 (0.34%) | 238 (1.30%) | Feeds::SourcesController#update 30, Admin::BillboardCampaignsController#show 15 |
| range-3 k4 | – | 18.93% (53/280) | 5.00% (42/840) | 3.57% (30/840) | 3.57% (30/840) | 100.00% (140/140) / 100.00% (140/140) | 61 (0.48%) | 338 (1.89%) | Feeds::SourcesController#update 30, Admin::BillboardCampaignsController#show 15 |
| range-2 k4 share 0.5% | – | 17.14% (48/280) | 5.48% (46/840) | 3.57% (30/840) | 3.57% (30/840) | 0.00% (0/140) / 0.00% (0/140) | 76 (0.55%) | 239 (1.30%) | Feeds::SourcesController#update 30, Admin::BillboardCampaignsController#show 15 |
| env k4 | – | 65.36% (183/280) | 41.67% (350/840) | 6.90% (58/840) | 4.76% (40/840) | 100.00% (140/140) / 100.00% (140/140) | 36 (0.28%) | 135 (0.77%) | AgentSessionsController#show 42, Admin::CommentsController#show 40 |
| env k4 share 0.5% | – | 11.43% (32/280) | 4.05% (34/840) | 3.57% (30/840) | 3.57% (30/840) | 0.00% (0/140) / 0.00% (0/140) | 85 (0.61%) | 191 (0.99%) | Feeds::SourcesController#update 30, AgentSessionsController#show 1 |
| pred99 k4 | – | 98.21% (275/280) | 96.43% (810/840) | 56.43% (474/840) | 86.19% (724/840) | 100.00% (140/140) / 100.00% (140/140) | 30 (0.25%) | 167 (0.98%) | Admin::UsersController#send_email_confirmation 35, Api::V1::Admin::UsersController#update_status 35 |
| rank k4 | – | 100.00% (280/280) | 100.00% (840/840) | 92.38% (776/840) | 100.00% (840/840) | 100.00% (140/140) / 100.00% (140/140) | 27 (0.21%) | 65 (0.38%) | EmailAuthorizationsController#verify 56, Admin::UsersController#full_delete 56 |
| range-2 k4 r1 | – | 100.00% (280/280) | 100.00% (840/840) | 59.05% (496/840) | 58.21% (489/840) | 100.00% (140/140) / 100.00% (140/140) | 40 (0.33%) | 181 (1.02%) | TagsController#edit 37, TagsController#update 37 |
| env k4 r1 | – | 100.00% (280/280) | 100.00% (840/840) | 67.38% (566/840) | 68.57% (576/840) | 100.00% (140/140) / 100.00% (140/140) | 37 (0.29%) | 101 (0.58%) | Admin::UsersController#full_delete 52, UsersController#add_org_admin 50 |
| range-2 k4 self-check | 92.86% (65/70) | 30.00% (6/20) | 13.33% (8/60) | 3.33% (2/60) | 3.33% (2/60) | 100.00% (10/10) / 100.00% (10/10) | 41 (0.33%) | 238 (1.28%) | Feeds::SourcesController#update 2, Admin::BillboardCampaignsController#show 2 |
| env k4 self-check | 100.00% (70/70) | – | – | – | – | – / – | – | – |  |
| range-2 k5 | – | 12.50% (21/168) | 4.76% (16/336) | 3.57% (12/336) | 3.57% (12/336) | 100.00% (112/112) / 100.00% (112/112) | 43 (0.34%) | 235 (1.32%) | Feeds::SourcesController#update 12, Admin::BillboardCampaignsController#show 6 |
| range-3 k5 | – | 11.31% (19/168) | 3.57% (12/336) | 3.57% (12/336) | 3.57% (12/336) | 100.00% (112/112) / 100.00% (112/112) | 61 (0.48%) | 339 (1.91%) | Feeds::SourcesController#update 12, Admin::BillboardCampaignsController#show 6 |
| range-2 k5 share 0.5% | – | 11.31% (19/168) | 4.76% (16/336) | 3.57% (12/336) | 3.57% (12/336) | 0.00% (0/112) / 0.00% (0/112) | 75 (0.55%) | 240 (1.32%) | Feeds::SourcesController#update 12, Admin::BillboardCampaignsController#show 6 |
| env k5 | – | 58.93% (99/168) | 32.74% (110/336) | 4.76% (16/336) | 3.57% (12/336) | 100.00% (112/112) / 100.00% (112/112) | 36 (0.28%) | 135 (0.77%) | AgentSessionsController#show 22, Admin::CommentsController#show 22 |
| env k5 share 0.5% | – | 7.14% (12/168) | 3.57% (12/336) | 3.57% (12/336) | 3.57% (12/336) | 0.00% (0/112) / 0.00% (0/112) | 85 (0.61%) | 191 (0.99%) | Feeds::SourcesController#update 12 |
| pred99 k5 | – | 94.64% (159/168) | 89.29% (300/336) | 48.21% (162/336) | 81.85% (275/336) | 100.00% (112/112) / 100.00% (112/112) | 27 (0.23%) | 132 (0.78%) | ArticleApprovalsController#create 22, VideosController#new 22 |
| rank k5 | – | 100.00% (168/168) | 100.00% (336/336) | 88.69% (298/336) | 99.70% (335/336) | 100.00% (112/112) / 100.00% (112/112) | 26 (0.21%) | 65 (0.37%) | Admin::UsersController#verify_email_ownership 28, IncomingWebhooks::MailchimpUnsubscribesController#create 28 |
| range-2 k5 r1 | – | 100.00% (168/168) | 100.00% (336/336) | 47.62% (160/336) | 47.32% (159/336) | 100.00% (112/112) / 100.00% (112/112) | 40 (0.32%) | 181 (1.02%) | TagsController#update 22, Admin::ConsumerAppsController#index 21 |
| env k5 r1 | – | 100.00% (168/168) | 100.00% (336/336) | 57.14% (192/336) | 58.63% (197/336) | 100.00% (112/112) / 100.00% (112/112) | 37 (0.29%) | 101 (0.58%) | Admin::UsersController#full_delete 27, ArticleApprovalsController#create 27 |
| range-2 k5 self-check | 78.57% (44/56) | 16.67% (6/36) | 8.33% (6/72) | 2.78% (2/72) | 2.78% (2/72) | 100.00% (24/24) / 100.00% (24/24) | 42 (0.33%) | 236 (1.31%) | Admin::BillboardCampaignsController#show 3, Feeds::SourcesController#update 2 |
| env k5 self-check | 100.00% (56/56) | – | – | – | – | – / – | – | – |  |

## osm: openstreetmap-website, PARALLEL_WORKERS=1, 8 + 2 planted

Processes per capture: 1. Kinds compared: request, job, mail. Rows: 11620, of which 11170 are identical in every run of every capture.

| Variant | Declined | One compare | CI job (any) | CI job (same row) | CI job (merged) | Plant: one / CI | Action d95 median | Action d95 p90 | Rows flagged most |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| aa1 (0.1 rule) | – | 0.00% (0/336) | 0.00% (0/1680) | 0.00% (0/1680) | 0.00% (0/1680) | 100.00% (112/112) / 100.00% (112/112) | 21 (0.48%) | 26 (1.32%) |  |
| range-2 k2 | – | 0.00% (0/168) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (56/56) / 100.00% (56/56) | 20 (0.47%) | 24 (1.30%) |  |
| range-3 k2 | – | 0.00% (0/168) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (56/56) / 100.00% (56/56) | 20 (0.47%) | 27 (1.32%) |  |
| range-2 k2 share 0.5% | – | 0.00% (0/168) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (56/56) / 100.00% (56/56) | 24 (0.54%) | 60 (1.30%) |  |
| env k2 | – | 0.00% (0/168) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (56/56) / 100.00% (56/56) | 21 (0.48%) | 27 (1.33%) |  |
| env k2 share 0.5% | – | 0.00% (0/168) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (56/56) / 100.00% (56/56) | 26 (0.56%) | 60 (1.33%) |  |
| pred99 k2 | – | 0.00% (0/168) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (56/56) / 100.00% (56/56) | 22 (0.70%) | 112 (2.19%) |  |
| rank k2 | – | 0.00% (0/168) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (56/56) / 100.00% (56/56) | 20 (0.46%) | 24 (1.30%) |  |
| range-2 k2 r1 | – | 24.40% (41/168) | 7.14% (60/840) | 7.14% (60/840) | 7.14% (60/840) | 100.00% (56/56) / 100.00% (56/56) | 21 (0.48%) | 26 (1.31%) | Oauth2ApplicationsController#new 30, parsers/message_ids_parser.rb:4870 21 |
| env k2 r1 | – | 24.40% (41/168) | 7.14% (60/840) | 7.14% (60/840) | 7.14% (60/840) | 100.00% (56/56) / 100.00% (56/56) | 21 (0.48%) | 28 (1.32%) | Oauth2ApplicationsController#new 30, parsers/message_ids_parser.rb:4870 21 |
| range-2 k3 | – | 0.00% (0/280) | 0.00% (0/1120) | 0.00% (0/1120) | 0.00% (0/1120) | 100.00% (112/112) / 100.00% (112/112) | 20 (0.46%) | 24 (1.29%) |  |
| range-3 k3 | – | 0.00% (0/280) | 0.00% (0/1120) | 0.00% (0/1120) | 0.00% (0/1120) | 100.00% (112/112) / 100.00% (112/112) | 20 (0.47%) | 27 (1.32%) |  |
| range-2 k3 share 0.5% | – | 0.00% (0/280) | 0.00% (0/1120) | 0.00% (0/1120) | 0.00% (0/1120) | 100.00% (112/112) / 100.00% (112/112) | 24 (0.53%) | 60 (1.29%) |  |
| env k3 | – | 0.00% (0/280) | 0.00% (0/1120) | 0.00% (0/1120) | 0.00% (0/1120) | 100.00% (112/112) / 100.00% (112/112) | 21 (0.49%) | 28 (1.33%) |  |
| env k3 share 0.5% | – | 0.00% (0/280) | 0.00% (0/1120) | 0.00% (0/1120) | 0.00% (0/1120) | 100.00% (112/112) / 100.00% (112/112) | 26 (0.57%) | 60 (1.33%) |  |
| pred99 k3 | – | 0.00% (0/280) | 0.00% (0/1120) | 0.00% (0/1120) | 0.00% (0/1120) | 100.00% (112/112) / 100.00% (112/112) | 20 (0.48%) | 25 (1.29%) |  |
| rank k3 | – | 0.00% (0/280) | 0.00% (0/1120) | 0.00% (0/1120) | 0.00% (0/1120) | 100.00% (112/112) / 100.00% (112/112) | 20 (0.46%) | 23 (1.29%) |  |
| range-2 k3 r1 | – | 19.64% (55/280) | 5.36% (60/1120) | 5.36% (60/1120) | 5.36% (60/1120) | 100.00% (112/112) / 100.00% (112/112) | 21 (0.47%) | 25 (1.29%) | parsers/message_ids_parser.rb:4870 35, Oauth2ApplicationsController#new 30 |
| env k3 r1 | – | 19.64% (55/280) | 5.36% (60/1120) | 5.36% (60/1120) | 5.36% (60/1120) | 100.00% (112/112) / 100.00% (112/112) | 21 (0.48%) | 28 (1.32%) | parsers/message_ids_parser.rb:4870 35, Oauth2ApplicationsController#new 30 |
| range-2 k3 self-check | 0.00% (0/56) | 0.00% (0/280) | 0.00% (0/1120) | 0.00% (0/1120) | 0.00% (0/1120) | 100.00% (112/112) / 100.00% (112/112) | 20 (0.46%) | 24 (1.29%) |  |
| env k3 self-check | 0.00% (0/56) | 0.00% (0/280) | 0.00% (0/1120) | 0.00% (0/1120) | 0.00% (0/1120) | 100.00% (112/112) / 100.00% (112/112) | 21 (0.49%) | 28 (1.33%) |  |
| range-2 k4 | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 20 (0.46%) | 23 (1.29%) |  |
| range-3 k4 | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 20 (0.47%) | 28 (1.32%) |  |
| range-2 k4 share 0.5% | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 24 (0.53%) | 60 (1.29%) |  |
| env k4 | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 21 (0.49%) | 28 (1.33%) |  |
| env k4 share 0.5% | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 26 (0.57%) | 60 (1.33%) |  |
| pred99 k4 | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 20 (0.46%) | 23 (1.29%) |  |
| rank k4 | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 20 (0.46%) | 23 (1.29%) |  |
| range-2 k4 r1 | – | 16.07% (45/280) | 3.57% (30/840) | 3.57% (30/840) | 3.57% (30/840) | 100.00% (140/140) / 100.00% (140/140) | 21 (0.47%) | 25 (1.29%) | parsers/message_ids_parser.rb:4870 35, Oauth2ApplicationsController#new 15 |
| env k4 r1 | – | 16.07% (45/280) | 3.57% (30/840) | 3.57% (30/840) | 3.57% (30/840) | 100.00% (140/140) / 100.00% (140/140) | 21 (0.48%) | 28 (1.32%) | parsers/message_ids_parser.rb:4870 35, Oauth2ApplicationsController#new 15 |
| range-2 k4 self-check | 0.00% (0/70) | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 20 (0.46%) | 23 (1.29%) |  |
| env k4 self-check | 0.00% (0/70) | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 21 (0.49%) | 28 (1.33%) |  |
| range-2 k5 | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 20 (0.46%) | 23 (1.29%) |  |
| range-3 k5 | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 20 (0.47%) | 28 (1.32%) |  |
| range-2 k5 share 0.5% | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 24 (0.53%) | 60 (1.29%) |  |
| env k5 | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 21 (0.49%) | 28 (1.33%) |  |
| env k5 share 0.5% | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 26 (0.57%) | 60 (1.33%) |  |
| pred99 k5 | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 20 (0.46%) | 23 (1.29%) |  |
| rank k5 | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 20 (0.46%) | 23 (1.29%) |  |
| range-2 k5 r1 | – | 13.69% (23/168) | 1.79% (6/336) | 1.79% (6/336) | 1.79% (6/336) | 100.00% (112/112) / 100.00% (112/112) | 21 (0.46%) | 24 (1.29%) | parsers/message_ids_parser.rb:4870 21, Oauth2ApplicationsController#new 3 |
| env k5 r1 | – | 13.69% (23/168) | 1.79% (6/336) | 1.79% (6/336) | 1.79% (6/336) | 100.00% (112/112) / 100.00% (112/112) | 21 (0.48%) | 28 (1.32%) | parsers/message_ids_parser.rb:4870 21, Oauth2ApplicationsController#new 3 |
| range-2 k5 self-check | 0.00% (0/56) | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 20 (0.46%) | 23 (1.29%) |  |
| env k5 self-check | 0.00% (0/56) | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 21 (0.49%) | 28 (1.33%) |  |

## campfire: Campfire, PARALLEL_WORKERS=1, 8 + 2 planted

Processes per capture: 1. Kinds compared: request, job, cable. Rows: 7341, of which 7148 are identical in every run of every capture.

| Variant | Declined | One compare | CI job (any) | CI job (same row) | CI job (merged) | Plant: one / CI | Action d95 median | Action d95 p90 | Rows flagged most |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| aa1 (0.1 rule) | – | 15.77% (53/336) | 1.43% (24/1680) | 0.71% (12/1680) | 0.89% (15/1680) | 100.00% (112/112) / 100.00% (112/112) | 27 (0.39%) | 124 (3.26%) | Users::BansController#create 36, Messages::ByBotsController#update 15 |
| range-2 k2 | – | 14.88% (25/168) | 1.19% (10/840) | 0.71% (6/840) | 0.95% (8/840) | 100.00% (56/56) / 100.00% (56/56) | 25 (0.36%) | 121 (2.96%) | Users::BansController#create 15, Messages::ByBotsController#update 9 |
| range-3 k2 | – | 14.88% (25/168) | 1.19% (10/840) | 0.71% (6/840) | 0.95% (8/840) | 100.00% (56/56) / 100.00% (56/56) | 33 (0.48%) | 171 (4.26%) | Users::BansController#create 15, Messages::ByBotsController#update 9 |
| range-2 k2 share 0.5% | – | 0.60% (1/168) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (56/56) / 100.00% (56/56) | 45 (0.56%) | 137 (2.96%) | FirstRunsController#show 1 |
| env k2 | – | 1.79% (3/168) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (56/56) / 100.00% (56/56) | 30 (0.38%) | 74 (1.98%) | FirstRunsController#show 1, Messages::ByBotsController#update 1 |
| env k2 share 0.5% | – | 0.60% (1/168) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (56/56) / 100.00% (56/56) | 49 (0.63%) | 119 (1.98%) | FirstRunsController#show 1 |
| pred99 k2 | – | 35.71% (60/168) | 15.24% (128/840) | 5.00% (42/840) | 15.36% (129/840) | 100.00% (56/56) / 100.00% (56/56) | 149 (2.01%) | 705 (18.43%) | Users::BansController#destroy 18, Users::BansController#create 13 |
| rank k2 | – | 73.81% (124/168) | 52.86% (444/840) | 23.57% (198/840) | 49.76% (418/840) | 100.00% (56/56) / 100.00% (56/56) | 24 (0.33%) | 42 (0.81%) | Users::BansController#destroy 36, Accounts::JoinCodesController#create 36 |
| range-2 k2 r1 | – | 73.21% (123/168) | 52.14% (438/840) | 19.52% (164/840) | 20.12% (169/840) | 100.00% (56/56) / 100.00% (56/56) | 26 (0.34%) | 112 (3.09%) | Accounts::JoinCodesController#create 30, Rooms::RefreshesController#show 24 |
| env k2 r1 | – | 72.62% (122/168) | 51.67% (434/840) | 20.00% (168/840) | 20.71% (174/840) | 100.00% (56/56) / 100.00% (56/56) | 27 (0.36%) | 67 (1.84%) | Accounts::JoinCodesController#create 30, Rooms::RefreshesController#show 24 |
| range-2 k3 | – | 12.14% (34/280) | 0.71% (8/1120) | 0.36% (4/1120) | 0.54% (6/1120) | 100.00% (112/112) / 100.00% (112/112) | 25 (0.36%) | 120 (3.03%) | Users::BansController#create 28, Messages::ByBotsController#update 6 |
| range-3 k3 | – | 12.14% (34/280) | 0.71% (8/1120) | 0.36% (4/1120) | 0.54% (6/1120) | 100.00% (112/112) / 100.00% (112/112) | 35 (0.49%) | 170 (4.28%) | Users::BansController#create 28, Messages::ByBotsController#update 6 |
| range-2 k3 share 0.5% | – | 0.00% (0/280) | 0.00% (0/1120) | 0.00% (0/1120) | 0.00% (0/1120) | 100.00% (112/112) / 100.00% (112/112) | 45 (0.55%) | 137 (3.03%) |  |
| env k3 | – | 0.00% (0/280) | 0.00% (0/1120) | 0.00% (0/1120) | 0.00% (0/1120) | 100.00% (112/112) / 100.00% (112/112) | 30 (0.38%) | 75 (2.02%) |  |
| env k3 share 0.5% | – | 0.00% (0/280) | 0.00% (0/1120) | 0.00% (0/1120) | 0.00% (0/1120) | 100.00% (112/112) / 100.00% (112/112) | 52 (0.63%) | 119 (2.02%) |  |
| pred99 k3 | – | 58.93% (165/280) | 33.93% (380/1120) | 10.71% (120/1120) | 32.32% (362/1120) | 100.00% (112/112) / 100.00% (112/112) | 28 (0.39%) | 128 (3.31%) | Users::BansController#destroy 40, Accounts::JoinCodesController#create 40 |
| rank k3 | – | 67.14% (188/280) | 42.86% (480/1120) | 15.18% (170/1120) | 43.21% (484/1120) | 100.00% (112/112) / 100.00% (112/112) | 24 (0.32%) | 42 (0.81%) | Users::BansController#destroy 55, Accounts::JoinCodesController#create 55 |
| range-2 k3 r1 | – | 67.14% (188/280) | 43.57% (488/1120) | 10.18% (114/1120) | 10.80% (121/1120) | 100.00% (112/112) / 100.00% (112/112) | 25 (0.34%) | 113 (2.94%) | Accounts::JoinCodesController#create 40, Users::BansController#destroy 35 |
| env k3 r1 | – | 65.71% (184/280) | 41.61% (466/1120) | 9.46% (106/1120) | 9.46% (106/1120) | 100.00% (112/112) / 100.00% (112/112) | 28 (0.37%) | 69 (1.84%) | Accounts::JoinCodesController#create 40, Users::BansController#destroy 35 |
| range-2 k3 self-check | 37.50% (21/56) | 17.14% (30/175) | 1.14% (8/700) | 0.57% (4/700) | 0.71% (5/700) | 100.00% (70/70) / 100.00% (70/70) | 25 (0.36%) | 117 (3.05%) | Users::BansController#create 25, Messages::ByBotsController#update 5 |
| env k3 self-check | 5.36% (3/56) | 0.00% (0/265) | 0.00% (0/1060) | 0.00% (0/1060) | 0.00% (0/1060) | 100.00% (106/106) / 100.00% (106/106) | 30 (0.38%) | 75 (2.02%) |  |
| range-2 k4 | – | 12.86% (36/280) | 0.00% (0/840) | 0.00% (0/840) | 0.12% (1/840) | 100.00% (140/140) / 100.00% (140/140) | 26 (0.36%) | 119 (2.95%) | Users::BansController#create 35, Messages::ByBotsController#update 1 |
| range-3 k4 | – | 12.86% (36/280) | 0.00% (0/840) | 0.00% (0/840) | 0.12% (1/840) | 100.00% (140/140) / 100.00% (140/140) | 36 (0.49%) | 170 (4.26%) | Users::BansController#create 35, Messages::ByBotsController#update 1 |
| range-2 k4 share 0.5% | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 45 (0.55%) | 137 (2.95%) |  |
| env k4 | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 30 (0.38%) | 75 (2.02%) |  |
| env k4 share 0.5% | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 52 (0.63%) | 119 (2.02%) |  |
| pred99 k4 | – | 52.50% (147/280) | 26.67% (224/840) | 7.86% (66/840) | 32.86% (276/840) | 100.00% (140/140) / 100.00% (140/140) | 24 (0.34%) | 80 (2.13%) | Accounts::UsersController#update 35, Users::BansController#create 35 |
| rank k4 | – | 63.21% (177/280) | 36.67% (308/840) | 10.48% (88/840) | 38.21% (321/840) | 100.00% (140/140) / 100.00% (140/140) | 24 (0.32%) | 41 (0.81%) | Accounts::JoinCodesController#create 50, Users::BansController#destroy 50 |
| range-2 k4 r1 | – | 62.14% (174/280) | 36.43% (306/840) | 5.71% (48/840) | 5.95% (50/840) | 100.00% (140/140) / 100.00% (140/140) | 24 (0.34%) | 112 (2.92%) | Users::BansController#destroy 35, Rooms::OpensController#create 35 |
| env k4 r1 | – | 61.07% (171/280) | 35.24% (296/840) | 5.00% (42/840) | 5.00% (42/840) | 100.00% (140/140) / 100.00% (140/140) | 28 (0.37%) | 69 (1.84%) | Users::BansController#destroy 35, Rooms::OpensController#create 35 |
| range-2 k4 self-check | 44.29% (31/70) | 21.15% (33/156) | 0.00% (0/468) | 0.00% (0/468) | 0.00% (0/468) | 100.00% (78/78) / 100.00% (78/78) | 26 (0.36%) | 116 (2.95%) | Users::BansController#create 33 |
| env k4 self-check | 0.00% (0/70) | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 30 (0.38%) | 75 (2.02%) |  |
| range-2 k5 | – | 12.50% (21/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 26 (0.36%) | 117 (2.89%) | Users::BansController#create 21 |
| range-3 k5 | – | 12.50% (21/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 37 (0.49%) | 167 (4.21%) | Users::BansController#create 21 |
| range-2 k5 share 0.5% | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 45 (0.55%) | 137 (2.89%) |  |
| env k5 | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 30 (0.38%) | 75 (2.02%) |  |
| env k5 share 0.5% | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 52 (0.63%) | 119 (2.02%) |  |
| pred99 k5 | – | 47.62% (80/168) | 22.02% (74/336) | 7.14% (24/336) | 28.27% (95/336) | 100.00% (112/112) / 100.00% (112/112) | 23 (0.33%) | 66 (1.75%) | Accounts::UsersController#update 21, Users::BansController#create 21 |
| rank k5 | – | 62.50% (105/168) | 35.71% (120/336) | 10.12% (34/336) | 33.63% (113/336) | 100.00% (112/112) / 100.00% (112/112) | 23 (0.32%) | 38 (0.81%) | Accounts::JoinCodesController#create 27, Users::BansController#destroy 27 |
| range-2 k5 r1 | – | 57.74% (97/168) | 30.36% (102/336) | 4.17% (14/336) | 4.17% (14/336) | 100.00% (112/112) / 100.00% (112/112) | 24 (0.34%) | 110 (2.87%) | Users::BansController#destroy 21, Users::BansController#create 21 |
| env k5 r1 | – | 57.14% (96/168) | 29.76% (100/336) | 3.57% (12/336) | 3.57% (12/336) | 100.00% (112/112) / 100.00% (112/112) | 28 (0.37%) | 69 (1.84%) | Users::BansController#destroy 21, Rooms::OpensController#create 21 |
| range-2 k5 self-check | 62.50% (35/56) | 33.33% (21/63) | 0.00% (0/126) | 0.00% (0/126) | 0.00% (0/126) | 100.00% (42/42) / 100.00% (42/42) | 26 (0.35%) | 107 (2.89%) | Users::BansController#create 21 |
| env k5 self-check | 0.00% (0/56) | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 30 (0.38%) | 75 (2.02%) |  |

## hackatime: Hackatime, PARALLEL_WORKERS=1, 8 + 2 planted

Processes per capture: 1. Kinds compared: request, job, mail. Rows: 9561, of which 9104 are identical in every run of every capture.

| Variant | Declined | One compare | CI job (any) | CI job (same row) | CI job (merged) | Plant: one / CI | Action d95 median | Action d95 p90 | Rows flagged most |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| aa1 (0.1 rule) | – | 9.52% (32/336) | 3.33% (56/1680) | 3.33% (56/1680) | 3.45% (58/1680) | 85.71% (96/112) / 85.71% (96/112) | 28 (1.24%) | 144 (3.30%) | Settings::GoalsController#create 18, My::ProjectRepoMappingsController#index 14 |
| range-2 k2 | – | 8.93% (15/168) | 2.86% (24/840) | 2.86% (24/840) | 2.98% (25/840) | 94.64% (53/56) / 92.86% (52/56) | 27 (1.21%) | 132 (3.29%) | Settings::GoalsController#create 9, My::ProjectRepoMappingsController#index 6 |
| range-3 k2 | – | 8.93% (15/168) | 2.86% (24/840) | 2.86% (24/840) | 2.86% (24/840) | 53.57% (30/56) / 53.57% (30/56) | 38 (1.53%) | 196 (4.35%) | Settings::GoalsController#create 9, My::ProjectRepoMappingsController#index 6 |
| range-2 k2 share 0.5% | – | 5.36% (9/168) | 2.14% (18/840) | 2.14% (18/840) | 2.14% (18/840) | 94.64% (53/56) / 92.86% (52/56) | 28 (1.21%) | 132 (3.29%) | Settings::GoalsController#create 9 |
| env k2 | – | 11.90% (20/168) | 5.95% (50/840) | 5.95% (50/840) | 5.00% (42/840) | 100.00% (56/56) / 100.00% (56/56) | 30 (1.22%) | 84 (3.21%) | My::ProjectRepoMappingsController#index 11, Settings::GoalsController#create 9 |
| env k2 share 0.5% | – | 5.36% (9/168) | 2.14% (18/840) | 2.14% (18/840) | 2.14% (18/840) | 64.29% (36/56) / 64.29% (36/56) | 30 (1.22%) | 122 (3.21%) | Settings::GoalsController#create 9 |
| pred99 k2 | – | 46.43% (78/168) | 27.86% (234/840) | 21.43% (180/840) | 36.79% (309/840) | 28.57% (16/56) / 28.57% (16/56) | 168 (5.16%) | 653 (16.24%) | logger/log_device.rb:33 30, logger/log_device.rb:33 30 |
| rank k2 | – | 91.67% (154/168) | 84.05% (706/840) | 60.95% (512/840) | 75.95% (638/840) | 100.00% (56/56) / 100.00% (56/56) | 24 (0.99%) | 37 (2.48%) | Settings::GoalsController#create 54, PullRepoCommitsJob#perform 48 |
| range-2 k2 r1 | – | 66.67% (112/168) | 48.33% (406/840) | 25.24% (212/840) | 25.24% (212/840) | 100.00% (56/56) / 100.00% (56/56) | 24 (1.02%) | 56 (3.05%) | Settings::GoalsController#create 30, addressable/uri.rb:424 30 |
| env k2 r1 | – | 66.07% (111/168) | 44.29% (372/840) | 23.33% (196/840) | 26.31% (221/840) | 100.00% (56/56) / 100.00% (56/56) | 25 (1.06%) | 50 (2.98%) | PullRepoCommitsJob#perform 36, Settings::GoalsController#create 30 |
| range-2 k3 | – | 1.79% (5/280) | 0.71% (8/1120) | 0.71% (8/1120) | 0.71% (8/1120) | 96.43% (108/112) / 96.43% (108/112) | 28 (1.21%) | 140 (3.32%) | Settings::GoalsController#create 3, My::ProjectRepoMappingsController#index 2 |
| range-3 k3 | – | 1.79% (5/280) | 0.71% (8/1120) | 0.71% (8/1120) | 0.71% (8/1120) | 35.71% (40/112) / 35.71% (40/112) | 40 (1.57%) | 201 (4.23%) | Settings::GoalsController#create 3, My::ProjectRepoMappingsController#index 2 |
| range-2 k3 share 0.5% | – | 1.07% (3/280) | 0.54% (6/1120) | 0.54% (6/1120) | 0.54% (6/1120) | 96.43% (108/112) / 96.43% (108/112) | 28 (1.21%) | 140 (3.32%) | Settings::GoalsController#create 3 |
| env k3 | – | 2.14% (6/280) | 1.07% (12/1120) | 1.07% (12/1120) | 1.07% (12/1120) | 100.00% (112/112) / 100.00% (112/112) | 30 (1.23%) | 85 (3.21%) | Settings::GoalsController#create 3, My::ProjectRepoMappingsController#index 3 |
| env k3 share 0.5% | – | 1.07% (3/280) | 0.54% (6/1120) | 0.54% (6/1120) | 0.54% (6/1120) | 49.11% (55/112) / 49.11% (55/112) | 31 (1.23%) | 122 (3.21%) | Settings::GoalsController#create 3 |
| pred99 k3 | – | 44.64% (125/280) | 24.82% (278/1120) | 16.61% (186/1120) | 26.52% (297/1120) | 100.00% (112/112) / 100.00% (112/112) | 30 (1.28%) | 118 (3.26%) | logger/log_device.rb:33 40, Doorkeeper::ApplicationsController#create 40 |
| rank k3 | – | 80.71% (226/280) | 65.54% (734/1120) | 44.11% (494/1120) | 56.70% (635/1120) | 100.00% (112/112) / 100.00% (112/112) | 24 (0.99%) | 38 (2.48%) | Settings::GoalsController#create 70, Settings::GoalsController#update 68 |
| range-2 k3 r1 | – | 47.86% (134/280) | 24.29% (272/1120) | 12.50% (140/1120) | 12.68% (142/1120) | 100.00% (112/112) / 100.00% (112/112) | 23 (1.04%) | 65 (3.09%) | PullRepoCommitsJob#perform 55, addressable/uri.rb:424 40 |
| env k3 r1 | – | 47.14% (132/280) | 23.57% (264/1120) | 12.86% (144/1120) | 14.46% (162/1120) | 100.00% (112/112) / 100.00% (112/112) | 25 (1.11%) | 51 (2.98%) | PullRepoCommitsJob#perform 55, addressable/uri.rb:424 40 |
| range-2 k3 self-check | 26.79% (15/56) | 2.44% (5/205) | 0.98% (8/820) | 0.98% (8/820) | 0.98% (8/820) | 98.78% (81/82) / 98.78% (81/82) | 28 (1.19%) | 140 (3.36%) | Settings::GoalsController#create 3, My::ProjectRepoMappingsController#index 2 |
| env k3 self-check | 32.14% (18/56) | 3.16% (6/190) | 1.58% (12/760) | 1.58% (12/760) | 1.58% (12/760) | 100.00% (76/76) / 100.00% (76/76) | 30 (1.23%) | 85 (3.21%) | Settings::GoalsController#create 3, My::ProjectRepoMappingsController#index 3 |
| range-2 k4 | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 99.29% (139/140) / 99.29% (139/140) | 27 (1.22%) | 139 (3.34%) |  |
| range-3 k4 | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 21.43% (30/140) / 21.43% (30/140) | 39 (1.58%) | 201 (4.18%) |  |
| range-2 k4 share 0.5% | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 99.29% (139/140) / 99.29% (139/140) | 28 (1.22%) | 139 (3.34%) |  |
| env k4 | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 100.00% (140/140) / 100.00% (140/140) | 30 (1.23%) | 85 (3.21%) |  |
| env k4 share 0.5% | – | 0.00% (0/280) | 0.00% (0/840) | 0.00% (0/840) | 0.00% (0/840) | 35.71% (50/140) / 35.71% (50/140) | 31 (1.23%) | 122 (3.21%) |  |
| pred99 k4 | – | 33.21% (93/280) | 14.29% (120/840) | 8.57% (72/840) | 15.12% (127/840) | 100.00% (140/140) / 100.00% (140/140) | 24 (1.04%) | 71 (3.01%) | AttemptProjectRepoMappingJob#perform 35, logger/log_device.rb:33 30 |
| rank k4 | – | 72.50% (203/280) | 52.38% (440/840) | 33.10% (278/840) | 43.93% (369/840) | 100.00% (140/140) / 100.00% (140/140) | 24 (0.97%) | 36 (2.48%) | Settings::GoalsController#update 56, Settings::GoalsController#create 56 |
| range-2 k4 r1 | – | 36.79% (103/280) | 13.33% (112/840) | 7.38% (62/840) | 7.38% (62/840) | 100.00% (140/140) / 100.00% (140/140) | 23 (1.04%) | 69 (2.98%) | PullRepoCommitsJob#perform 50, AttemptProjectRepoMappingJob#perform 35 |
| env k4 r1 | – | 36.43% (102/280) | 13.57% (114/840) | 7.62% (64/840) | 8.69% (73/840) | 100.00% (140/140) / 100.00% (140/140) | 25 (1.11%) | 51 (2.98%) | PullRepoCommitsJob#perform 50, AttemptProjectRepoMappingJob#perform 35 |
| range-2 k4 self-check | 7.14% (5/70) | 0.00% (0/260) | 0.00% (0/780) | 0.00% (0/780) | 0.00% (0/780) | 99.23% (129/130) / 99.23% (129/130) | 27 (1.21%) | 139 (3.34%) |  |
| env k4 self-check | 8.57% (6/70) | 0.00% (0/256) | 0.00% (0/768) | 0.00% (0/768) | 0.00% (0/768) | 100.00% (128/128) / 100.00% (128/128) | 30 (1.23%) | 85 (3.21%) |  |
| range-2 k5 | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 27 (1.22%) | 138 (3.32%) |  |
| range-3 k5 | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 10.71% (12/112) / 10.71% (12/112) | 39 (1.57%) | 200 (4.15%) |  |
| range-2 k5 share 0.5% | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 28 (1.22%) | 138 (3.32%) |  |
| env k5 | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 30 (1.23%) | 85 (3.21%) |  |
| env k5 share 0.5% | – | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 24.11% (27/112) / 24.11% (27/112) | 31 (1.23%) | 122 (3.21%) |  |
| pred99 k5 | – | 27.38% (46/168) | 11.90% (40/336) | 8.93% (30/336) | 12.20% (41/336) | 100.00% (112/112) / 100.00% (112/112) | 23 (1.03%) | 56 (3.05%) | AttemptProjectRepoMappingJob#perform 21, logger/log_device.rb:33 12 |
| rank k5 | – | 67.26% (113/168) | 44.05% (148/336) | 25.00% (84/336) | 33.93% (114/336) | 100.00% (112/112) / 100.00% (112/112) | 23 (0.96%) | 36 (2.48%) | Settings::GoalsController#create 28, Settings::GoalsController#update 28 |
| range-2 k5 r1 | – | 30.36% (51/168) | 9.52% (32/336) | 5.36% (18/336) | 5.36% (18/336) | 100.00% (112/112) / 100.00% (112/112) | 23 (1.05%) | 72 (2.98%) | PullRepoCommitsJob#perform 27, AttemptProjectRepoMappingJob#perform 21 |
| env k5 r1 | – | 30.36% (51/168) | 9.52% (32/336) | 5.36% (18/336) | 5.95% (20/336) | 100.00% (112/112) / 100.00% (112/112) | 25 (1.11%) | 51 (2.98%) | PullRepoCommitsJob#perform 27, AttemptProjectRepoMappingJob#perform 21 |
| range-2 k5 self-check | 0.00% (0/56) | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 27 (1.22%) | 138 (3.32%) |  |
| env k5 self-check | 0.00% (0/56) | 0.00% (0/168) | 0.00% (0/336) | 0.00% (0/336) | 0.00% (0/336) | 100.00% (112/112) / 100.00% (112/112) | 30 (1.23%) | 85 (3.21%) |  |

## Across the one-process sets

Worst set per variant among the sets with enough captures for it (k + 1 for one compare, k + 2 for the CI job).

| Variant | Sets measured | Worst one compare | Worst CI job (merged) | Sets with a CI false alarm |
| --- | --- | ---: | ---: | --- |
| aa1 (0.1 rule) | forem, osm, campfire, hackatime | forem 65.48% (220/336) | forem 15.54% (261/1680) | forem, campfire, hackatime |
| range-2 k2 | forem, osm, campfire, hackatime | forem 64.88% (109/168) | forem 15.60% (131/840) | forem, campfire, hackatime |
| range-3 k2 | forem, osm, campfire, hackatime | forem 54.76% (92/168) | forem 12.38% (104/840) | forem, campfire, hackatime |
| range-2 k2 share 0.5% | forem, osm, campfire, hackatime | forem 40.48% (68/168) | forem 8.10% (68/840) | forem, hackatime |
| env k2 | forem, osm, campfire, hackatime | forem 82.14% (138/168) | forem 25.24% (212/840) | forem, hackatime |
| env k2 share 0.5% | forem, osm, campfire, hackatime | forem 33.33% (56/168) | forem 7.14% (60/840) | forem, hackatime |
| pred99 k2 | forem, osm, campfire, hackatime | forem 99.40% (167/168) | forem 94.64% (795/840) | forem, campfire, hackatime |
| rank k2 | forem, osm, campfire, hackatime | forem 100.00% (168/168) | forem 100.00% (840/840) | forem, campfire, hackatime |
| range-2 k2 r1 | forem, osm, campfire, hackatime | forem 100.00% (168/168) | forem 90.95% (764/840) | forem, osm, campfire, hackatime |
| env k2 r1 | forem, osm, campfire, hackatime | forem 100.00% (168/168) | forem 95.12% (799/840) | forem, osm, campfire, hackatime |
| range-2 k3 | forem, osm, campfire, hackatime | forem 36.43% (102/280) | forem 4.91% (55/1120) | forem, campfire, hackatime |
| range-3 k3 | forem, osm, campfire, hackatime | forem 30.00% (84/280) | forem 4.82% (54/1120) | forem, campfire, hackatime |
| range-2 k3 share 0.5% | forem, osm, campfire, hackatime | forem 25.00% (70/280) | forem 3.84% (43/1120) | forem, hackatime |
| env k3 | forem, osm, campfire, hackatime | forem 72.50% (203/280) | forem 9.46% (106/1120) | forem, hackatime |
| env k3 share 0.5% | forem, osm, campfire, hackatime | forem 18.57% (52/280) | forem 4.29% (48/1120) | forem, hackatime |
| pred99 k3 | forem, osm, campfire, hackatime | forem 98.57% (276/280) | forem 93.57% (1048/1120) | forem, campfire, hackatime |
| rank k3 | forem, osm, campfire, hackatime | forem 100.00% (280/280) | forem 100.00% (1120/1120) | forem, campfire, hackatime |
| range-2 k3 r1 | forem, osm, campfire, hackatime | forem 100.00% (280/280) | forem 74.38% (833/1120) | forem, osm, campfire, hackatime |
| env k3 r1 | forem, osm, campfire, hackatime | forem 100.00% (280/280) | forem 82.14% (920/1120) | forem, osm, campfire, hackatime |
| range-2 k3 self-check | forem, osm, campfire, hackatime | campfire 17.14% (30/175) | hackatime 0.98% (8/820) | campfire, hackatime |
| env k3 self-check | forem, osm, campfire, hackatime | hackatime 3.16% (6/190) | hackatime 1.58% (12/760) | hackatime |
| range-2 k4 | forem, osm, campfire, hackatime | forem 22.14% (62/280) | forem 3.57% (30/840) | forem, campfire |
| range-3 k4 | forem, osm, campfire, hackatime | forem 18.93% (53/280) | forem 3.57% (30/840) | forem, campfire |
| range-2 k4 share 0.5% | forem, osm, campfire, hackatime | forem 17.14% (48/280) | forem 3.57% (30/840) | forem |
| env k4 | forem, osm, campfire, hackatime | forem 65.36% (183/280) | forem 4.76% (40/840) | forem |
| env k4 share 0.5% | forem, osm, campfire, hackatime | forem 11.43% (32/280) | forem 3.57% (30/840) | forem |
| pred99 k4 | forem, osm, campfire, hackatime | forem 98.21% (275/280) | forem 86.19% (724/840) | forem, campfire, hackatime |
| rank k4 | forem, osm, campfire, hackatime | forem 100.00% (280/280) | forem 100.00% (840/840) | forem, campfire, hackatime |
| range-2 k4 r1 | forem, osm, campfire, hackatime | forem 100.00% (280/280) | forem 58.21% (489/840) | forem, osm, campfire, hackatime |
| env k4 r1 | forem, osm, campfire, hackatime | forem 100.00% (280/280) | forem 68.57% (576/840) | forem, osm, campfire, hackatime |
| range-2 k4 self-check | forem, osm, campfire, hackatime | forem 30.00% (6/20) | forem 3.33% (2/60) | forem |
| env k4 self-check | forem, osm, campfire, hackatime | forem – | forem – |  |
| range-2 k5 | forem, osm, campfire, hackatime | forem 12.50% (21/168) | forem 3.57% (12/336) | forem |
| range-3 k5 | forem, osm, campfire, hackatime | campfire 12.50% (21/168) | forem 3.57% (12/336) | forem |
| range-2 k5 share 0.5% | forem, osm, campfire, hackatime | forem 11.31% (19/168) | forem 3.57% (12/336) | forem |
| env k5 | forem, osm, campfire, hackatime | forem 58.93% (99/168) | forem 3.57% (12/336) | forem |
| env k5 share 0.5% | forem, osm, campfire, hackatime | forem 7.14% (12/168) | forem 3.57% (12/336) | forem |
| pred99 k5 | forem, osm, campfire, hackatime | forem 94.64% (159/168) | forem 81.85% (275/336) | forem, campfire, hackatime |
| rank k5 | forem, osm, campfire, hackatime | forem 100.00% (168/168) | forem 99.70% (335/336) | forem, campfire, hackatime |
| range-2 k5 r1 | forem, osm, campfire, hackatime | forem 100.00% (168/168) | forem 47.32% (159/336) | forem, osm, campfire, hackatime |
| env k5 r1 | forem, osm, campfire, hackatime | forem 100.00% (168/168) | forem 58.63% (197/336) | forem, osm, campfire, hackatime |
| range-2 k5 self-check | forem, osm, campfire, hackatime | campfire 33.33% (21/63) | forem 2.78% (2/72) | forem |
| env k5 self-check | forem, osm, campfire, hackatime | forem – | forem – |  |
