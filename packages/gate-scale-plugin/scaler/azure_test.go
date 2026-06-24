package scaler

import (
	"context"
	"errors"
	"testing"

	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/appcontainers/armappcontainers"
)

func TestAzureContainerAppClientEnsureRunningUsesContainerAppsSDK(t *testing.T) {
	apps := &fakeContainerApps{}
	client := AzureContainerAppClient{
		SubscriptionID:   "sub",
		ResourceGroup:    "rg",
		ContainerAppName: "minecraft",
		Apps:             apps,
	}

	if err := client.EnsureRunning(context.Background()); err != nil {
		t.Fatalf("EnsureRunning() error = %v", err)
	}
	if !apps.sawGet || !apps.sawNudge {
		t.Fatalf("sdk calls = get:%t nudge:%t, want both", apps.sawGet, apps.sawNudge)
	}
	if apps.resourceGroup != "rg" || apps.name != "minecraft" {
		t.Fatalf("target = %s/%s, want rg/minecraft", apps.resourceGroup, apps.name)
	}
}

func TestAzureContainerAppClientEnsureRunningReturnsStatusError(t *testing.T) {
	client := AzureContainerAppClient{
		SubscriptionID:   "sub",
		ResourceGroup:    "rg",
		ContainerAppName: "minecraft",
		Apps:             &fakeContainerApps{getErr: errors.New("status failed")},
	}

	if err := client.EnsureRunning(context.Background()); err == nil {
		t.Fatal("EnsureRunning() error = nil, want status error")
	}
}

func TestSDKContainerAppsClientNudgePatch(t *testing.T) {
	app := wakeNudgePatch()
	if app.Properties == nil || app.Properties.Template == nil || app.Properties.Template.Scale == nil {
		t.Fatalf("patch did not include properties.template.scale")
	}
	scale := app.Properties.Template.Scale
	if scale.MinReplicas == nil || *scale.MinReplicas != 0 {
		t.Fatalf("minReplicas = %v, want 0", scale.MinReplicas)
	}
	if scale.MaxReplicas == nil || *scale.MaxReplicas != 1 {
		t.Fatalf("maxReplicas = %v, want 1", scale.MaxReplicas)
	}
}

func TestAzureContainerAppClientSkipsManagementWhenUnconfigured(t *testing.T) {
	apps := &fakeContainerApps{}
	client := AzureContainerAppClient{Apps: apps}

	if err := client.EnsureRunning(context.Background()); err != nil {
		t.Fatalf("EnsureRunning() error = %v", err)
	}
	if apps.sawGet || apps.sawNudge {
		t.Fatalf("sdk calls = get:%t nudge:%t, want none", apps.sawGet, apps.sawNudge)
	}
}

type fakeContainerApps struct {
	sawGet        bool
	sawNudge      bool
	resourceGroup string
	name          string
	getErr        error
	nudgeErr      error
}

func (f *fakeContainerApps) Get(_ context.Context, resourceGroup, name string) (armappcontainers.ContainerApp, error) {
	f.sawGet = true
	f.resourceGroup = resourceGroup
	f.name = name
	return armappcontainers.ContainerApp{}, f.getErr
}

func (f *fakeContainerApps) Nudge(_ context.Context, resourceGroup, name string) error {
	f.sawNudge = true
	f.resourceGroup = resourceGroup
	f.name = name
	return f.nudgeErr
}
