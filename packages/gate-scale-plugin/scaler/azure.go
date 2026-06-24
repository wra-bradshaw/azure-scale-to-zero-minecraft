package scaler

import (
	"context"
	"fmt"
	"net"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/arm"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/appcontainers/armappcontainers"
)

type AzureContainerAppClient struct {
	SubscriptionID   string
	ResourceGroup    string
	ContainerAppName string
	WakeHost         string
	WakePort         int
	Credential       azcore.TokenCredential
	ClientOptions    *arm.ClientOptions
	Apps             containerAppManager
}

func (c AzureContainerAppClient) EnsureRunning(ctx context.Context) error {
	// Opening the internal TCP socket is the primary Container Apps wake path.
	// A cold app may refuse or time out while KEDA starts a replica, so this is
	// intentionally best-effort; readiness is handled by the Minecraft health loop.
	c.triggerTCPWake(ctx)

	if !c.managementConfigured() {
		return nil
	}

	apps, err := c.containerApps()
	if err != nil {
		return err
	}
	if _, err := apps.Get(ctx, c.ResourceGroup, c.ContainerAppName); err != nil {
		return err
	}
	return apps.Nudge(ctx, c.ResourceGroup, c.ContainerAppName)
}

func (c AzureContainerAppClient) triggerTCPWake(ctx context.Context) {
	if c.WakeHost == "" || c.WakePort == 0 {
		return
	}
	dialCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	conn, err := (&net.Dialer{}).DialContext(dialCtx, "tcp", fmt.Sprintf("%s:%d", c.WakeHost, c.WakePort))
	if err == nil {
		_ = conn.Close()
	}
}

func (c AzureContainerAppClient) containerApps() (containerAppManager, error) {
	if c.Apps != nil {
		return c.Apps, nil
	}
	credential := c.Credential
	if credential == nil {
		var err error
		credential, err = azidentity.NewDefaultAzureCredential(nil)
		if err != nil {
			return nil, err
		}
	}
	client, err := armappcontainers.NewContainerAppsClient(c.SubscriptionID, credential, c.ClientOptions)
	if err != nil {
		return nil, err
	}
	return sdkContainerAppsClient{client: client}, nil
}

func (c AzureContainerAppClient) managementConfigured() bool {
	return c.SubscriptionID != "" && c.ResourceGroup != "" && c.ContainerAppName != ""
}

type containerAppManager interface {
	Get(context.Context, string, string) (armappcontainers.ContainerApp, error)
	Nudge(context.Context, string, string) error
}

type sdkContainerAppsClient struct {
	client *armappcontainers.ContainerAppsClient
}

func (c sdkContainerAppsClient) Get(ctx context.Context, resourceGroup, name string) (armappcontainers.ContainerApp, error) {
	res, err := c.client.Get(ctx, resourceGroup, name, nil)
	if err != nil {
		return armappcontainers.ContainerApp{}, fmt.Errorf("azure container app status failed: %w", err)
	}
	return res.ContainerApp, nil
}

func (c sdkContainerAppsClient) Nudge(ctx context.Context, resourceGroup, name string) error {
	_, err := c.client.BeginUpdate(ctx, resourceGroup, name, wakeNudgePatch(), nil)
	if err != nil {
		return fmt.Errorf("azure container app wake nudge failed: %w", err)
	}
	return nil
}

func wakeNudgePatch() armappcontainers.ContainerApp {
	minReplicas := int32(0)
	maxReplicas := int32(1)
	return armappcontainers.ContainerApp{
		Properties: &armappcontainers.ContainerAppProperties{
			Template: &armappcontainers.Template{
				Scale: &armappcontainers.Scale{
					MinReplicas: &minReplicas,
					MaxReplicas: &maxReplicas,
				},
			},
		},
	}
}
