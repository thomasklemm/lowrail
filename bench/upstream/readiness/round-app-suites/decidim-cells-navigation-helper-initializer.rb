# Classification shim (Lowrail Decidim round, main only): cells-rails includes FormHelper, which on Rails main no
# longer brings link_to/button_to (NavigationHelper). Mirrors a cells-rails fix.
Cell::ViewModel.include(ActionView::Helpers::NavigationHelper) if defined?(ActionView::Helpers::NavigationHelper)
