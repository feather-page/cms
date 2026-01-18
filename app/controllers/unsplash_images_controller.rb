class UnsplashImagesController < ApplicationController
  def search
    query = params[:q]
    results = search_unsplash(query)

    render json: format_results(results)
  end

  def create
    result = fetch_photo
    image = create_image_from(result)

    render json: response_for(image)
  end

  private

  def search_unsplash(query)
    return [] if query.blank? || query.length < 2

    Unsplash::Client.new.search(query)
  end

  def fetch_photo
    Unsplash::Client.new.photo(params[:unsplash_id])
  end

  def create_image_from(result)
    return nil unless result

    image = RemoteImageCreator.new(current_site, nil).create_from(result.full_url)
    return nil unless image

    image.update(unsplash_data: result.unsplash_data)
    image
  end

  def format_results(results)
    results.map { |r| result_hash(r) }
  end

  def result_hash(result)
    {
      id: result.id,
      description: result.description,
      thumbnail_url: result.thumbnail_url,
      photographer_name: result.photographer[:name],
      photographer_url: result.photographer[:profile_url]
    }
  end

  def response_for(image)
    if image
      { success: true, image_id: image.id }
    else
      { success: false }
    end
  end
end
