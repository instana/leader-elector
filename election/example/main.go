/*
Copyright 2015 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	election "k8s.io/contrib/election/lib"

	"github.com/golang/glog"
	"github.com/spf13/pflag"
	"k8s.io/kubernetes/pkg/api"
	"k8s.io/kubernetes/pkg/client/restclient"
	client "k8s.io/kubernetes/pkg/client/unversioned"
	kubectl_util "k8s.io/kubernetes/pkg/kubectl/cmd/util"
)

var (
	pflags = pflag.NewFlagSet(
		`elector --election=<name>`,
		pflag.ExitOnError)
	name      = pflags.String("election", "", "The name of the election")
	id        = pflags.String("id", "", "The id of this participant")
	namespace = pflags.String("election-namespace", api.NamespaceDefault, "The Kubernetes namespace for this election")
	ttl       = pflags.Duration("ttl", 10*time.Second, "The TTL for this election")
	inCluster = pflags.Bool("use-cluster-credentials", false, "Should this request use cluster credentials?")
	addr      = pflags.String("http", "", "If non-empty, stand up a simple webserver that reports the leader state")

	leader = &LeaderData{}
)

func makeClient() (*client.Client, error) {
	var cfg *restclient.Config
	var err error

	if *inCluster {
		if cfg, err = restclient.InClusterConfig(); err != nil {
			return nil, err
		}
	} else {
		clientConfig := kubectl_util.DefaultClientConfig(pflags)
		if cfg, err = clientConfig.ClientConfig(); err != nil {
			return nil, err
		}
	}
	return client.New(cfg)
}

// LeaderData represents information about the current leader
type LeaderData struct {
	Name string `json:"name"`
}

func webHandler(res http.ResponseWriter, _ *http.Request) {
	data, err := json.Marshal(leader)
	if err != nil {
		glog.V(4).Infof("Could not marshal leader: %s", leader)
		res.WriteHeader(http.StatusInternalServerError)
		res.Write([]byte(err.Error()))
		return
	}
	res.WriteHeader(http.StatusOK)
	res.Write(data)
}

func webHealthHandler(res http.ResponseWriter, _ *http.Request) {
	if leader == nil || leader.Name == "" {
		glog.V(4).Info("Invalid leader")
		res.WriteHeader(http.StatusInternalServerError)
		_, err := io.WriteString(res, "Invalid leader")
		if err != nil {
			glog.Errorf("Could not write the response: %v", err)
		}
		return
	}

	glog.V(4).Infof("Valid leader set with name: %s", leader.Name)
	res.WriteHeader(http.StatusOK)
	_, err := io.WriteString(res, fmt.Sprintf("Valid leader set: %v", leader))
	if err != nil {
		glog.Errorf("Could not write the response: %v", err)
	}
}

func validateFlags() {
	if len(*id) == 0 {
		glog.Fatal("--id cannot be empty")
	}
	if len(*name) == 0 {
		glog.Fatal("--election cannot be empty")
	}
}

func main() {
	err := pflags.Parse(os.Args)
	if err != nil {
		glog.Errorf("Could not parse OS arguments: %s", os.Args)
		return
	}
	validateFlags()

	env, exists := os.LookupEnv("GLOG_vmodule")
	if exists {
		glog.Infof("Environment variable GLOG_vmodule is set to: %s", env)
		err := flag.Set("vmodule", env)
		if err != nil {
			glog.Errorf("Could not set vmodule=%s", env, err)
		}
	}

	env, exists = os.LookupEnv("GLOG_v")
	if exists {
		glog.Infof("Environment variable GLOG_v is set to: %s", env)
		err := flag.Set("v", env)
		if err != nil {
			glog.Errorf("Could not set v=%s", env, err)
		}
	}

	kubeClient, err := makeClient()
	if err != nil {
		glog.Fatalf("error connecting to the client: %v", err)
	}

	fn := func(str string) {
		leader.Name = str
		glog.V(3).Infof("%s is the leader\n", leader.Name)
	}

	e, err := election.NewElection(*name, *id, *namespace, *ttl, fn, kubeClient)
	if err != nil {
		glog.Fatalf("failed to create election: %v", err)
	}
	go election.RunElection(e)

	if len(*addr) > 0 {
		http.HandleFunc("/health", webHealthHandler)
		http.HandleFunc("/", webHandler)
		http.ListenAndServe(*addr, nil)
	} else {
		select {}
	}
}
