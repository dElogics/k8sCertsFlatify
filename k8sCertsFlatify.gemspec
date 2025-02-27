# gem build -o /home/de/docs/Practice/Software/docker/k8sCertsFlatify/k8sCertsFlatify.gem k8sCertsFlatify.gemspec
Gem::Specification.new do |lg|
	lg.author = "dE"
	lg.files = [ "README", "bin/k8sCertsFlatify.rb"]
	lg.executables = ["k8sCertsFlatify.rb"]
	lg.name = "k8sCertsFlatify"
	lg.platform = "universal-linux"
	lg.summary = "A script which extracts 1 or multiple tls/ssl certificates from a kubernetes cluster."
	lg.description = "A script which extracts 1 or multiple tls/ssl certificates from a kubernetes cluster to PWD.
NOTE: Will not check the TLS certificate of the connecting kubernetes cluster as of the current time.
Switch --kubeconfig/-c <kubernetes kubeconfig file>. If not present default to ~/.kube/config
switch --namespaces/-n -- Namespace to dump certificates in. If not present, will dump certificates of all namespaces.
--context/-k -- The context to use in the kubeconfig file.
--dumpdir/-d -- Dump certificates to this directory instead of PWD
Will dump certificates in PWD in a directory with the name as the DNS to which the certificate belongs."
	lg.version = "0.1.3"
	lg.email = "de.techno@gmail.com"
	lg.homepage = "http://delogics.blogspot.com"
	lg.license = "Apache-2.0"
	lg.add_runtime_dependency 'curb','~>1'
	lg.add_runtime_dependency 'oj','~> 3'
	lg.add_runtime_dependency 'kubeclient','~> 4'
end
