#! /usr/bin/ruby
# NOTE: Will not check the TLS certificate of the connecting kubernetes cluster as of the current time.
require 'curb'
require 'oj'
require 'base64'
require 'fileutils.rb'
require 'optparse'
require 'kubeclient'

# Stores options as passed in switches to the script
@switchOptions = Hash.new
opts = OptionParser.new
kubecfg = nil
opts.banner = "Dump certificates which exists in a Kubernetes cluster to flat files in PWD."
opts.on('-k', '--context CONTEXT', 'The context to use in the kubeconfig file.') {
	|kubecontext|
	@switchOptions[:context] = kubecontext
}
opts.on('-c', '--kubeconfig KUBECONFIG', 'If not present default to ~/.kube/config') {
	|kubeconfig|
	kubecfg = kubeconfig
}
opts.on('-n', '--namespaces NAMESPACE', 'Namespace to dump certificates in. If not present, will dump certificates of all namespaces.') {
	|ns|
	@switchOptions[:ns] = ns
}
opts.on('-d', '--dumpdir DIR', 'Dump certificates to this directory instead of PWD') {
	|dir|
	Dir.chdir(dir)
}
opts.parse!

kubecfg = "#{ENV['HOME']}/.kube/config" if kubecfg == nil
if @switchOptions[:context] == nil
	kubeContext = Kubeclient::Config.read(kubecfg).context
else
	kubeContext = Kubeclient::Config.read(kubecfg).context(@switchOptions[:context])
end
@bearer = "Bearer #{kubeContext.auth_options[:bearer_token]}"
# API endpoint templates for all ingress
@allingendpoint = "/apis/networking.k8s.io/v1/ingresses"
# API endpoint templates for single ingress
@aningendpoint = "/apis/networking.k8s.io/v1/namespaces/$${namespace}/ingresses"
# old k8s
# @allingendpoint = "apis/networking.k8s.io/v1beta1/ingresses"
@secendpoint = "/api/v1/namespaces/$${namespace}/secrets/$${name}"
@server = kubeContext.api_endpoint.chomp('/')
# TODO: Could not get CA certificate.
# puts kubeContext.ssl_options[:cert_store].class
# GC
kubeContext = nil
kubecfg = nil


# TODO: Could not get CA certificate.
@ca = nil
allinghash = String.new
Oj.default_options = { :symbol_keys => true, :bigdecimal_as_decimal => true, :mode => :compat, 'load' => :compat }

# will return an array. First element being the certificate, 2nd the secret. Will return false in case of issues (like secrets does not hold a certificate)
def getCerts(name, namespace)
	if name.class != String
		puts "name not present for namespace #{namespace}"
		return nil
	end
	if namespace.class != String
		puts "namespace not present for name #{name}"
		return nil
	end
	endpoint = @secendpoint.dup
	endpoint.gsub!(%r{\$\$\{name\}}, name)
	endpoint.gsub!(%r{\$\$\{namespace\}}, namespace)
	thesec = String.new
	k8sconnection = Curl::Easy.new(@server + endpoint) {
		|request|
		request.headers = { :Authorization => @bearer }
	# TODO: Could not get CA certificate.
		# request.cacert = @ca
		request.ssl_verify_host = false
		request.ssl_verify_peer = false
		request.http_get
		thesec = Oj.load(request.body_str)
	}
	if thesec[:type] != 'kubernetes.io/tls'
		puts "Secret with name #{name} in namespace #{namespace} is not of type kubernetes.io/tls"
		return nil
	end
	if (thesec[:data][:'tls.crt'] == nil || thesec[:data][:'tls.key'] == nil)
		puts "tls.crt or/and tls.key keys in the secret is empty for secret #{namespace}/#{name}"
		return nil
	end
	return [Base64.strict_decode64(thesec[:data][:'tls.crt']), Base64.strict_decode64(thesec[:data][:'tls.key'])]
end

# select endpoint based on mode of operation -- single certificate or all of them.
endpoint = nil
if @switchOptions[:ns] == nil
	endpoint = @allingendpoint
else
	endpoint = @aningendpoint.dup.gsub!(%r{\$\$\{namespace\}}, @switchOptions[:ns])
end
puts endpoint
k8sconnection = Curl::Easy.new(@server + endpoint) {
	|request|
	request.headers = { :Authorization => @bearer }
	# TODO: Could not get CA certificate.
	# request.cacert = @ca
	request.ssl_verify_host = false
	request.ssl_verify_peer = false
	request.http_get
	allinghash = Oj.load(request.body_str)
}

k8sconnection = nil
allinghash[:items].each {
	|ingress|
	ingNamespace = ingress[:metadata][:namespace]
	if ingress == nil
		puts "ingress entry was empty in namespace #{ingNamespace}"
	elsif ingress[:spec] == nil
		puts "ingress spec was empty for ingress #{ingress[:metadata][:name]} in namespace #{ingNamespace}"
	elsif ingress[:spec][:tls] == nil
		puts "No tls certificate specified in ingress #{ingress[:metadata][:name]} in namespace #{ingNamespace}"
	elsif ingress[:spec][:tls].length >= 1
		ingress[:spec][:tls].each {
			|secretref|
			if certpair = getCerts(secretref[:secretName], ingNamespace)
				begin
					FileUtils.mkdir(secretref[:hosts])
				rescue Errno::EEXIST
				end
				secretref[:hosts].each {
					|host|
					IO.binwrite("#{host}/cert.crt", certpair[0])
					IO.binwrite("#{host}/key.key", certpair[1])
				}
			end
		}
	else
		puts "No TLS entry found for ingress #{ingress[:metadata][:name]} in namespace #{ingNamespace}"
	end
}
