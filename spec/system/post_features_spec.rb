describe 'Post features' do
  describe 'listing all posts' do
    it 'show all posts' do
      as_user do |user|
        site = create(:site, users: [user])
        posts = create_list(:post, 2, site:)

        visit site_posts_path(site)

        posts.each do |post|
          expect(page).to have_content(post.title)
        end
      end
    end
  end

  describe 'creating a short post' do
    it 'creates a short post' do
      as_user do |user|
        site = create(:site, users: [user])

        visit site_posts_path(site)
        click_on 'New Post'

        short_post_text = Faker::Lorem.characters(number: 299)
        fill_in_post_content(short_post_text)

        expect(page).to have_no_field('Title')
        expect(page).to have_no_field('Slug')

        click_on 'Create Post'

        expect(page).to have_content('Post was successfully created.')
        expect(Post.last.content.inspect).to include(short_post_text)
      end
    end
  end

  describe 'creating a longer post' do
    it 'creates a longer post' do
      as_user do |user|
        site = create(:site, users: [user])

        visit site_posts_path(site)
        click_on 'New Post'

        long_post_text = Faker::Lorem.characters(number: 300)
        fill_in_post_content(long_post_text)
        fill_in 'Title', with: 'A long post'

        click_on 'Create Post'

        expect(page).to have_content('Post was successfully created.')

        last_post = Post.last

        expect(last_post.content.inspect).to include(long_post_text)
        expect(last_post.title).to eq('A long post')
      end
    end
  end

  describe 'editing a post' do
    it 'updated the post' do
      as_user do |user|
        site = create(:site, users: [user])
        post = create(:post, site:)

        visit site_posts_path(site)
        click_on 'Edit'

        post_attributes = attributes_for(:post)
        fill_in 'Title', with: post_attributes[:title]

        click_on 'Update Post'

        expect(page).to have_content('Post was successfully updated.')
        expect(page).to have_content(post_attributes[:title])
        expect(post.reload.title).to eq(post_attributes[:title])
      end
    end
  end

  describe 'deleting a post' do
    it 'deletes the post' do
      as_user do |user|
        site = create(:site, users: [user])
        post = create(:post, site:)

        visit site_posts_path(site)
        accept_confirm do
          click_on 'Delete'
        end

        expect(page).to have_no_content(post.title)
      end
    end
  end

  private

  def fill_in_post_content(content)
    find('.codex-editor').click
    find('.codex-editor .ce-paragraph').send_keys(content)
    find('.codex-editor .ce-paragraph').native.send_keys(:return)

    # We need to wait for the content to be updated
    sleep 0.5
  end
end
