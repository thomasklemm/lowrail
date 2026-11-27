# r81 vs main (compare.rb)

| App | tests r81 | failing r81 | tests main | failing main | pass r81, fail main | fail r81, pass main |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| casa | 938 | | none | | | |
| chatwoot | none | | none | | | |
| discourse | 1771 | 0 | 10 | 0 | 0 | 0 |
| flow | 449 | | none | | | |
| loomio | 1491 | 0 | 995 | 0 | 0 | 0 |
| mastodon | 2131 | 4 | 2249 | 573 | 558 | 0 |
| sure | 1139 | | none | | | |

## discourse

No regressions.

Only on r81 (1771): .defer_topic_view; BreadcrumbList structured data; Plugin::Instance; RSS feeds; RSS feeds ignore current user; Returns a N with unicode group name; Showing hot topics from private categories; Showing top topics from private categories; Shows correct title if category list is set for homepage; Top

## loomio

No regressions.

Only on r81 (496): Admin::DashboardControllerTest#test_admin_dashboard_shows_twelve_operational_stats; Admin::DashboardControllerTest#test_dashboard_counts_users_by_current_credentials_and_latest_sign-in; Admin::GroupsControllerTest#test_admin_can_import_and_send_a_JSON_group_export; Admin::GroupsControllerTest#test_admin_can_render_the_user_export_report; Admin::GroupsControllerTest#test_admin_can_search_groups_from_the_filter_bar; Admin::GroupsControllerTest#test_admin_can_send_a_CSV_export_for_a_discarded_group; Admin::GroupsControllerTest#test_admin_can_show_a_subscribed_group_without_subscription_admin_routes; Admin::GroupsControllerTest#test_admin_can_show_and_edit_a_group; Admin::GroupsControllerTest#test_group_update_shows_validation_errors; Admin::UsersControllerTest#test_admin_can_create_a_one-time_sign-in_link

## mastodon

* Downloads a user backup
* Logs out the user and redirect
* Logs out the user and return a page to redirect to with a JSON request
* accepts for_bots parameter
* adds account to the list
* adds attributes to current span
* allows account in follow recommendations
* allows the requesting follower to follow
* approves account to appear in trends
* approves the user successfully
* assigns report to the requesting user
* bookmarks the status successfully
* bookmarks the status successfully and includes updated json
* cannot create a setting value for a non-admin key
* changes data policy and alert settings and returns expected JSON
* changes existing alert settings
* changes languages option
* changes notification policy and returns an updated json object
* changes notify option
* changes reblogs option
* changes the interaction policy, returns the updated status, and schedules distribution jobs
* clears notifications for the account
* contains webfinger and activitypub urls in link header
* create a record of the callback
* creates a blocking relation
* creates a collection and returns http success
* creates a collection item and returns http success
* creates a conversation mute
* creates a domain block
* creates a domain block with the expected domain name and severity
* creates a filter
* creates a follow request relation between user and target user
* creates a following relation between user and target user
* creates a marker
* creates a new backfill request
* creates a new featured tag for the requesting user
* creates a new provider
* creates a new subscription
* creates a new tag with the specified name
* creates a report
* creates a report including the collection ids
* creates a report including the status ids
* creates a scheduled status
* creates a user
* creates a username block
* creates a vote
* creates account_pin
* creates an OAuth App with the default scope
* creates an OAuth app
* creates an OAuth application with multiple redirect URIs
* creates an OAuth application with the website specified
* creates featured tag
* creates follow
* creates reaction
* deletes email domain block
* deletes selected username blocks
* deletes the account successfully
* deletes the allowed domain
* deletes the canonical email block
* deletes the collection and returns http success
* deletes the collection item and returns http success
* deletes the domain block
* deletes the ip block
* deletes the list
* deletes the specified domain block
* deletes the subscription
* destroys account_pin
* destroys prior subscription when creating new one
* destroys the conversation mute
* destroys the filter
* destroys the keyword
* destroys the notification
* destroys the reblog
* disables the target account
* discards the status and schedules removal as a redraft
* discards the status and schedules removal without the redraft flag
* dismisses announcement
* do not set cookies
* does not add the account to the list
* does not change settings
* does not create a backfill request
* does not create a provider and returns an error code
* does not create a scheduled status
* does not create a subscription
* does not create account note
* does not create role
* does not expose the client_id or client_secret
* does not have a next page
* does not include a next page link
* does not mute notifications
* does not remove any account from the list
* does not resend confirmation mail
* does not return HTTP success and does not have cache headers
* does not return avatar in response
* does not return blocked users
* does not set cookies
* does not set cookies or set public cache control
* does not start a synchronization job
* does not treat the request as signed
* does not updated the user record
* does nothing
* enables the user successfully
* enqueues a retrieval job and adds a header to inform the client
* fails to approve account
* fails to delete account
* fails to enable account
* fails to memorialize account
* fails to redownload
* fails to reject account
* fails to remove avatar
* fails to remove header
* fails to unblock email
* fails to unsensitive account
* fails to unsilence account
* fails to unsuspend account
* fails to verify signature
* falls back to a locale when region missing
* falls back to english when locale is missing
* favourites the status successfully
* favourites the status successfully and includes updated json
* features a deprecation header when requested via the alpha route
* gracefully handles invalid nested params
* handles the error and returns http empty
* has a Vary on Accept-Language
* has a Vary on Authorization
* has a Vary on Cookie
* has og:locale opengraph tag if the status has is written in a given language
* has valid opengraph tags
* hides results
* hides the collections that are not discoverable
* ignores the canonical_email_hash param
* ignores the feeble attempts at deception
* includes a link to the next page
* includes a next page link
* includes all items in the response
* keeps the interaction policy, returns the status, and does not schedule distribution jobs
* leaves the notification alone
* lists both the public and the private statuses
* lists the public status only
* logs action
* marks a check as ignored
* marks a check as not ignored
* marks report as resolved
* marks report as unresolved
* marks the target account as sensitive
* marks the target account as silenced
* marks the target account as suspended
* mutes notifications
* notifies the user about the action taken
* only includes the non-blocked account in the response
* only saves the scope once
* paginates correctly
* pins the status successfully
* pins the status successfully and returns updated json
* points next to other replies
* points next to other self-replies
* points next to replies from other people
* preserves existing quote approval policy
* queries mutes in range according to max_id
* queries mutes in range according to since_id
* queries the blocks in range according to max_id
* queries the blocks in range according to since_id
* queues a job to continue the given backfill request
* raises ActiveRecord::RecordNotFound
* raises an error
* reblogs the status
* redirects after a successful request
* redirects back and sets challenge passed at in session
* redirects on GET to new
* redirects on POST to create
* redirects successfully with missing action_category
* redirects to #new
* redirects to at-username page variation
* redirects to callback
* redirects to canonical URL
* redirects to confirm_settings_import_path
* redirects to correct original url
* redirects to enable otp
* redirects to file url
* redirects to login and confirms user
* redirects to login and queues worker
* redirects to login, confirms email, does not queue worker
* redirects to profile
* redirects to root
* redirects to root path
* redirects to settings
* redirects to sign in
* redirects to small style url
* redirects to streaming host
* redirects to success
* redirects to tag page and saves update log action for all attribute statuses
* redirects to the account collections page
* redirects to the change password page
* redirects to the original status
* redirects to the report page
* redirects with proper cache header
* rejects account from showing in trends
* removes duplicate account IDs from params
* removes the blocking relation between user and target user
* removes the featured tag
* removes the filter
* removes the follow
* removes the follow request
* removes the followed relation between user and target user
* removes the following relation between user and target user
* removes the muting relation between user and target user
* removes the specified account from the list but keeps other accounts in the list
* removes the subscription
* removes the user successfully and logs action
* renders ActivityPub Collection successfully
* renders ActivityPub FeaturedCollection object successfully
* renders ActivityPub FeaturedItem object successfully
* renders ActivityPub Note object
* renders ActivityPub Note object successfully
* renders ActivityPub representation successfully
* renders challenge, displays error, does not set session
* renders ips within range
* renders new page with success status
* renders reset password and retains password
* renders success page
* renders success page and updates subscription as confirmed
* renders successfully with partial ip address
* replaces old subscription on repeat calls
* responds with correct statuses
* responds with correct statuses with a tag
* responds with correct statuses with media
* responds with correct statuses with replies
* responds with missing
* responds with not found
* responds with the filter
* responds with the keyword
* responds with unprocessable and does not modify setting
* return http success
* return the correct blocked email domains
* returns CSV response with instance domain values
* returns HTTP N
* returns HTTP success with the appropriate profile
* returns JSON document pointing to node info
* returns JSON document with node info properties
* returns JSON with an html attribute
* returns JSON with correct data
* returns JSON with correct data after change too
* returns JSON with correct data on previously cached requests
* returns N
* returns N forbidden
* returns N gone
* returns N gone and mentions self-destruct
* returns N notifications
* returns N ok
* returns `N` (Bad Request)
* returns a CSV file with correct data
* returns a CSV with the accounts
* returns a CSV with the blocking accounts
* returns a CSV with the bookmarked statuses
* returns a CSV with the domains
* returns a CSV with the list
* returns a CSV with the muted accounts
* returns a JSON document with error details
* returns a JSON document with expected attributes
* returns a JSON version of the account
* returns a JSON version of the account and removes reach filter
* returns a JSON with the custom filters
* returns a N
* returns a N page as html
* returns a capped value
* returns a http 'moved_permanently' code
* returns a json response
* returns a json response for json accept header
* returns a json response for json format
* returns a list of accounts
* returns a notification group covering all notifications
* returns a private JSON version of the account
* returns a private signature JSON version of the account and updates the reach filter
* returns a quote post, as well as rate limit headers
* returns a standard HTML response
* returns a validation error
* returns account entity as N OK
* returns accounts followed by the given account
* returns accounts following the given account
* returns accounts in order of creation
* returns accounts in order of most recent status activity
* returns accounts who reblogged the status
* returns all accounts, including muted accounts
* returns all collections for the given account and http success
* returns all collections, including the ones that are not discoverable
* returns all matching accounts
* returns all reports
* returns all scopes requested for the given code
* returns all the requested scopes
* returns all unresolved reports
* returns all unresolved reports filed by the specified account
* returns all unresolved reports targeting the specified account
* returns an HTML page
* returns an account in "partial_accounts", with the expected keys
* returns an empty body
* returns an empty list
* returns an enumerable json with correct elements, excluding suspended accounts
* returns an enumerable json with correct elements, including suspended accounts
* returns an error
* returns an error and does not create a post
* returns appropriate http response code
* returns avatar in response
* returns conversations
* returns empty language matrix
* returns empty stylesheet
* returns error json
* returns error response
* returns everything but excluded type
* returns everything, but does not group favourites
* returns existing domain block in error
* returns expected headers
* returns expected notification types
* returns expected notification types, including filtered notifications
* returns expected notifications count
* returns expected response
* returns filter information
* returns http N
* returns http accepted
* returns http accepted, create an async job and schedules a job
* returns http authorization error
* returns http authorization error with json error
* returns http bad request
* returns http bad_request
* returns http content too large
* returns http empty
* returns http empty response
* returns http error
* returns http forbidden and error message
* returns http forbidden error
* returns http forbidden with error message
* returns http forbidden with private cache control headers
* returns http missing
* returns http not authorized
* returns http not found response
* returns http not found while also rendering the page
* returns http not_found
* returns http partial content
* returns http success and accounts json
* returns http success and accounts who favourited the status
* returns http success and activity json
* returns http success and activity json types and correct items count
* returns http success and available status
* returns http success and cache control and activity json types and correct items
* returns http success and correct media type
* returns http success and correct media type and cache headers and empty items
* returns http success and correct media type and correct items
* returns http success and correct media type and expected items
* returns http success and correct media type and headers and items
* returns http success and correct media type and vary header and items
* returns http success and creates notification permission
* returns http success and deletes the avatar, preserves the header, queues up distribution
* returns http success and destroys the notification request
* returns http success and eligible status
* returns http success and empty response
* returns http success and expected tag content
* returns http success and follower counts
* returns http success and header pagination links to prev and next
* returns http success and includes a header link
* returns http success and includes correct tag name
* returns http success and includes followed tags
* returns http success and includes supported languages
* returns http success and includes the favourites
* returns http success and ineligible status
* returns http success and json
* returns http success and json with known domains
* returns http success and recently used but not featured tags
* returns http success and removes reach filter
* returns http success and removes suggestion
* returns http success and removes the filter
* returns http success and returns app information
* returns http success and returns merged: false
* returns http success and returns merged: true
* returns http success and status json
* returns http success and statuses but not private ones
* returns http success and statuses of followed users
* returns http success and statuses quoting this post
* returns http success and the bookmarked statuses
* returns http success and the wrapstodon year
* returns http success and updates keyword and sends a filters_changed event
* returns http success and updates tag
* returns http success when server is functioning
* returns http success with a filter with keywords in json and creates a filter
* returns http success with accounts
* returns http success with an empty body and deletes the featured tag
* returns http success with correct json
* returns http success with correct media type and body
* returns http success with expected JSON
* returns http success with expected XML
* returns http success with expected content
* returns http success with expected statuses
* returns http success with media information
* returns http success with muted accounts
* returns http success with private cache control headers
* returns http success with updated JSON attributes
* returns http success with valid JSON response
* returns http success without json
* returns http success, preserves the avatar, deletes the header, queues up distribution
* returns http unauthorized
* returns http unauthorized with appropriate error
* returns http unprocessable content
* returns http unprocessable content and detailed errors
* returns http unprocessable entity
* returns http unprocessable entity with username error message
* returns invalid when the schema does not match
* returns items with other public or unlisted replies and correctly inlines replies and uses IDs
* returns items with thread author's replies
* returns json with expected attributes
* returns language matrix
* returns markers
* returns no conversation
* returns not found
* returns nothing
* returns only a single result
* returns only notifications from specified user
* returns only requested type
* returns only the canonical email blocks after since_id
* returns only the canonical email blocks before max_id
* returns only the default scope
* returns only the email domain blocks after since_id
* returns only the email domain blocks before max_id
* returns only the featured tags belonging to the requesting user
* returns only the followed accounts
* returns only the local accounts
* returns only the requested number of accounts
* returns only the requested number of allowed domains
* returns only the requested number of blocked accounts and sets link header pagination
* returns only the requested number of blocked domains
* returns only the requested number of canonical email blocks
* returns only the requested number of domain blocks
* returns only the requested number of email domain blocks
* returns only the requested number of favourites and sets pagination headers
* returns only the requested number of follow requests
* returns only the requested number of follow tags and sets pagination headers
* returns only the requested number of ip blocks
* returns only the requested number of muted accounts with pagination headers
* returns only the requested number of reports
* returns only the requested number of statuses
* returns only the requested number of statuses and sets pagination headers
* returns only the requested number of statuses with pagination headers
* returns only the requested number of tags
* returns only the resolved reports
* returns page with links to alternate resources
* returns pagination headers
* returns poll data and calls fetch remote service
* returns post with appropriate quote policy, as well as rate limit headers
* returns post with user default quote policy, as well as rate limit headers
* returns posts along with self replies
* returns rate limit headers
* returns serialized extra accounts in body
* returns server directory opt in data
* returns stylesheet from settings
* returns success
* returns success and includes opengraph meta tags
* returns success and marks the report as read
* returns success with private cache control headers
* returns the accounts in the requested list
* returns the app information correctly
* returns the blocked accounts
* returns the canonical_email_hash correctly
* returns the confirmation status successfully
* returns the correct CSP headers
* returns the correct accounts
* returns the correct allowed domains
* returns the correct blocked domain
* returns the correct blocked email domain
* returns the correct blocked ips
* returns the correct canonical email hashes
* returns the correct canonical_email_hash
* returns the correct ip block
* returns the correct items
* returns the correct result and headers
* returns the domains blocked by the requesting user
* returns the error in the json response
* returns the existing allowed domain name
* returns the existing filters successfully
* returns the expected accounts
* returns the expected allowed domain name
* returns the expected campaign
* returns the expected canonical email hash
* returns the expected content from accounts requesting to follow
* returns the expected domain block content
* returns the expected domain blocks
* returns the expected domain name
* returns the expected lists
* returns the expected statuses
* returns the expected statuses successfully
* returns the expected suggestions
* returns the expected tags
* returns the file with the expected headers
* returns the filter successfully
* returns the index page
* returns the link data
* returns the local discoverable account and the remote discoverable account
* returns the media
* returns the new list
* returns the poll data successfully
* returns the requested account successfully
* returns the requested canonical email block data correctly
* returns the requested list correctly
* returns the requested number of accounts, with pagination headers
* returns the requested number of notifications paginated
* returns the requested report content
* returns the response successfully
* returns the source properties of the status
* returns the tag
* returns the updated domain block
* returns the updated list and updates values
* returns unauthorized
* returns unprocessable entity
* revokes access tokens for the application and removes subscriptions and sends kill payload to streaming
* revokes the collection item and returns http success
* revokes the quote and returns HTTP success
* revokes the token and removes subscriptions
* saves alert settings
* saves category
* saves category and rule_ids
* saves push subscription with standard as false
* saves push subscriptions and returns expected JSON
* saves push subscriptions with valid params
* saves the value for a valid key
* sets private cache control
* sets the correct pagination headers
* sets the expected CSP headers
* shows confirmation page
* shows subscription details
* shows unsubscribe form
* starts a synchronization job
* successfully verifies signature
* successfuly verifies signature
* successfuly verifies signature after refreshing the account
* supports passing scope values as string
* suppress account from follow recommendations
* unassigns report from assignee
* unbookmarks the status successfully and includes updated json
* unfavourites the status successfully and includes updated json
* unpins the status successfully and includes updated json
* unsensitizes the account successfully
* unsilences the account successfully
* unsuspends the account successfully
* updates a marker
* updates account note
* updates filter_bots
* updates notification settings
* updates setting and responds with success
* updates the account
* updates the block severity
* updates the collection and returns http success
* updates the description
* updates the filter
* updates the filter successfully
* updates the keyword
* updates the report category
* updates the status
* updates the user's e-mail address
* updates username block
* uploads the file successfully and returns correct media content
* uses a specific region when provided
* uses a specific style of ISN timestamps

Only on r81 (12): 'Cache-Control' => include('public'),; 'Link' => include('activity+json'); 'Vary' => 'Accept, Accept-Language, Cookie',; (compared using ==); ); .to be_nil; expect(response.headers).to include(; expect(response.headers['Vary']); is expected to redirect to "/auth/sign_in"; is expected to redirect to "/authorize_interaction?uri=test"
