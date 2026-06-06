module Captain::UrlSafetyValidator
  class Error < StandardError; end

  PRIVATE_IP_RANGES = [
    IPAddr.new('127.0.0.0/8'),
    IPAddr.new('10.0.0.0/8'),
    IPAddr.new('172.16.0.0/12'),
    IPAddr.new('192.168.0.0/16'),
    IPAddr.new('169.254.0.0/16'),
    IPAddr.new('::1'),
    IPAddr.new('fc00::/7'),
    IPAddr.new('fe80::/10')
  ].freeze

  module_function

  def validate_url!(url)
    uri = URI.parse(url.to_s)
    raise Error, 'URL must use HTTPS' unless uri.scheme == 'https'
    raise Error, 'URL host is missing' if uri.host.blank?

    validate_hostname!(uri.host)
    uri
  rescue URI::InvalidURIError => e
    raise Error, e.message
  end

  def validate_hostname!(hostname)
    ip_address = IPAddr.new(Resolv.getaddress(hostname))
    raise Error, 'Request blocked: hostname resolves to private IP address' if PRIVATE_IP_RANGES.any? { |range| range.include?(ip_address) }
  rescue Resolv::ResolvError, SocketError => e
    raise Error, "DNS resolution failed: #{e.message}"
  end
end
