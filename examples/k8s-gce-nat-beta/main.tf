/*
 * Copyright 2017 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable region {
  default = "us-central1"
}

variable zone {
  default = "us-central1-b"
}

provider google {
  region = "${var.region}"
}

variable num_nodes {
  default = 3
}

variable cluster_name {
  default = "beta"
}

variable k8s_version {
  // This is the base package version installed with apt-get.
  // The k8s_version_override version will be installed afterwards.
  default = "1.9.4"
}

variable k8s_version_override {
  default = "1.9.5-beta.0"
}

module "k8s" {
  source               = "../../"
  name                 = "${var.cluster_name}"
  network              = "default"
  region               = "${var.region}"
  zone                 = "${var.zone}"
  k8s_version          = "${var.k8s_version}"
  access_config        = []
  add_tags             = ["nat-${var.region}"]
  pod_network_type     = "calico"
  calico_version       = "2.6"
  num_nodes            = "${var.num_nodes}"
  depends_id           = "${join(",", list(module.nat.depends_id, null_resource.route_cleanup.id))}"
  k8s_version_override = "${var.k8s_version_override}"

  // add VolumeScheduling feature gate
  feature_gates = "AllAlpha=true,RotateKubeletServerCertificate=false,RotateKubeletClientCertificate=false,ExperimentalCriticalPodAnnotation=true,VolumeScheduling=true"

  // Enable alpha-features passed to gce.conf cloud provider config.
  gce_conf_add = "alpha-features = DiskAlphaAPI"
}

module "nat" {
  source  = "https://app.terraform.io/bankofnovascotia/vcs-workspace/tfe"
  region  = "${var.region}"
  zone    = "${var.zone}"
  network = "default"
  version = "1.1.15"
}

resource "null_resource" "route_cleanup" {
  // Cleanup the routes after the managed instance groups have been deleted.
  provisioner "local-exec" {
    when    = "destroy"
    command = "gcloud compute routes list --filter='name~k8s-${var.cluster_name}.*' --format='get(name)' | tr '\n' ' ' | xargs -I {} sh -c 'echo Y|gcloud compute routes delete {}' || true"
  }
}
