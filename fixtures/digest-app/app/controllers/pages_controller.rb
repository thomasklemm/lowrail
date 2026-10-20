class PagesController < ApplicationController
  def show
    render inertia: "Page", props: {message: "Hello"}
  end
end
