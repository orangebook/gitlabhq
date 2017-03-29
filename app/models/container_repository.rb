class ContainerRepository < ActiveRecord::Base
  belongs_to :project

  validates :name, length: { minimum: 0, allow_nil: false }

  delegate :client, to: :registry
  before_destroy :delete_tags

  def registry
    @registry ||= begin
      token = Auth::ContainerRegistryAuthenticationService.full_access_token(path)

      url = Gitlab.config.registry.api_url
      host_port = Gitlab.config.registry.host_port

      ContainerRegistry::Registry.new(url, token: token, path: host_port)
    end
  end

  def path
    @path ||= [project.full_path, name].select(&:present?).join('/')
  end

  def tag(tag)
    ContainerRegistry::Tag.new(self, tag)
  end

  def manifest
    @manifest ||= client.repository_tags(self.path)
  end

  def tags
    return @tags if defined?(@tags)
    return [] unless manifest && manifest['tags']

    @tags = manifest['tags'].map do |tag|
      ContainerRegistry::Tag.new(self, tag)
    end
  end

  def blob(config)
    ContainerRegistry::Blob.new(self, config)
  end

  # TODO, specs needed
  #
  def has_tags?
    tags.any?
  end

  # TODO, add bang to this method
  #
  def delete_tags
    return unless tags

    digests = tags.map {|tag| tag.digest }.to_set
    digests.all? do |digest|
      client.delete_repository_tag(self.path, digest)
    end
  end

  # TODO, we will return a new ContainerRepository object here
  #
  def self.project_from_path(repository_path)
    ContainerRegistry::Path.new(repository_path)
      .repository_project
  end
end
