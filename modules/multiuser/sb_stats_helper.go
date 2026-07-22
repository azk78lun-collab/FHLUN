// lun-sb-stats queries the loopback-only sing-box V2Ray stats API.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"os"
	"time"

	api "github.com/sagernet/sing-box/experimental/v2rayapi"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func main() {
	server := flag.String("server", "127.0.0.1:10086", "loopback sing-box V2Ray API address")
	pattern := flag.String("pattern", "user>>>", "statistics name prefix")
	reset := flag.Bool("reset", false, "reset counters after reading")
	timeout := flag.Duration("timeout", 5*time.Second, "query timeout")
	flag.Parse()

	host, _, err := net.SplitHostPort(*server)
	if err != nil {
		fatalf("invalid server: %v", err)
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		fatalf("server must be a loopback address")
	}

	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()
	connection, err := grpc.NewClient(*server, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		fatalf("connect: %v", err)
	}
	defer connection.Close()
	request := &api.QueryStatsRequest{
		Pattern: *pattern,
		Reset_:  *reset,
	}
	methods := []string{
		"/experimental.v2rayapi.StatsService/QueryStats",
		"/v2ray.core.app.stats.command.StatsService/QueryStats",
		"/xray.app.stats.command.StatsService/QueryStats",
	}
	var response *api.QueryStatsResponse
	for _, method := range methods {
		candidate := new(api.QueryStatsResponse)
		if err = connection.Invoke(ctx, method, request, candidate); err == nil {
			response = candidate
			break
		}
	}
	if response == nil {
		fatalf("query: %v", err)
	}
	if err := json.NewEncoder(os.Stdout).Encode(response); err != nil {
		fatalf("encode: %v", err)
	}
}

func fatalf(format string, values ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", values...)
	os.Exit(1)
}
