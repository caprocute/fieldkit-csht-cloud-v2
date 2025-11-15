package main

import (
	"context"
	"encoding/hex"
	"flag"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"

	"github.com/golang/protobuf/proto"

	fkc "gitlab.com/fieldkit/fkc"

	pbapp "gitlab.com/fieldkit/libraries/app-protocol"
	pbdata "gitlab.com/fieldkit/libraries/data-protocol"
)

type options struct {
	Address   string
	Port      int
	Status    bool
	HexEncode bool
	Name      string
	Save      string

	ScanModules    bool
	ScanNetworks   bool
	GetReadings    bool
	TakeReadings   bool
	StartRecording bool
	StopRecording  bool

	Schedule string
	Wifi     string

	LoraClear             bool
	LoraDeviceEui         string
	LoraAppKey            string
	LoraJoinEui           string
	LoraAppSessionKey     string
	LoraNetworkSessionKey string
	LoraDeviceAddress     string
	LoraUplinkCounter     int
	LoraDownlinkCounter   int
	LoraFrequencyBand     int

	Module          int
	ResetModule     int
	ConfigureModule int

	FactoryReset bool

	TransmissionUrl   string
	TransmissionToken string

	List string
	Skip int

	DecodeApp          bool
	DecodeData         bool
	DecodeModuleConfig bool
	Varint             int
}

func main() {
	o := options{}

	flag.StringVar(&o.Address, "address", "", "ip address of the device")
	flag.IntVar(&o.Port, "port", 80, "port number")
	flag.BoolVar(&o.HexEncode, "hex", false, "hex encoding")
	flag.BoolVar(&o.Status, "status", false, "device status")
	flag.StringVar(&o.Name, "name", "", "name")
	flag.BoolVar(&o.GetReadings, "get", false, "")
	flag.BoolVar(&o.TakeReadings, "take", false, "")
	flag.BoolVar(&o.StartRecording, "start-recording", false, "")
	flag.BoolVar(&o.StopRecording, "stop-recording", false, "")
	flag.BoolVar(&o.ScanNetworks, "scan-networks", false, "")
	flag.BoolVar(&o.ScanModules, "scan-modules", false, "")
	flag.StringVar(&o.Save, "save", "", "save")

	flag.BoolVar(&o.LoraClear, "lora-clear", false, "lora-clear")
	flag.StringVar(&o.LoraDeviceEui, "lora-device-eui", "", "lora-device-eui")
	flag.StringVar(&o.LoraAppKey, "lora-app-key", "", "lora-app-key")
	flag.StringVar(&o.LoraJoinEui, "lora-join-eui", "", "lora-join-eui")
	flag.StringVar(&o.LoraAppSessionKey, "lora-app-session-key", "", "lora-app-session-key")
	flag.StringVar(&o.LoraNetworkSessionKey, "lora-network-session-key", "", "lora-network-session-key")
	flag.StringVar(&o.LoraDeviceAddress, "lora-device-address", "", "lora-device-address")
	flag.IntVar(&o.LoraUplinkCounter, "lora-uplink-counter", 0, "lora-uplink-counter")
	flag.IntVar(&o.LoraDownlinkCounter, "lora-downlink-counter", 0, "lora-downlink-counter")
	flag.IntVar(&o.LoraFrequencyBand, "lora-freq-band", 915, "lora band")
	flag.StringVar(&o.Schedule, "schedule", "", "schedule")

	flag.StringVar(&o.List, "ls", "", "path")
	flag.IntVar(&o.Skip, "skip", 0, "skip")

	flag.StringVar(&o.Wifi, "wifi", "", "wifi networks: ssid,password,ssid,password")

	flag.IntVar(&o.Module, "module", -1, "module")
	flag.IntVar(&o.ConfigureModule, "configure-module", -1, "configure module")
	flag.IntVar(&o.ResetModule, "reset-module", -1, "reset module")

	flag.IntVar(&o.Varint, "varint", 0, "show varint hex")

	flag.StringVar(&o.TransmissionUrl, "transmission-url", "", "transmission url")
	flag.StringVar(&o.TransmissionToken, "transmission-token", "", "transmission token")

	flag.BoolVar(&o.FactoryReset, "factory-reset", false, "factory reset")
	flag.BoolVar(&o.DecodeApp, "decode-app", false, "decode fk app communications")
	flag.BoolVar(&o.DecodeData, "decode-data", false, "decode fk data")
	flag.BoolVar(&o.DecodeModuleConfig, "decode-module-config", false, "decode fk module config")

	flag.Parse()

	ctx := context.Background()

	if o.Varint != 0 {
		bytes := proto.EncodeVarint(uint64(o.Varint))
		fmt.Printf("%v\n", hex.EncodeToString(bytes))
		return
	}

	if o.DecodeApp {
		if err := fkc.Decode(ctx, fkc.DecodeApp); err != nil {
			log.Fatalf("error: %v", err)
		}
		return
	}

	if o.DecodeModuleConfig {
		if err := fkc.Decode(ctx, fkc.DecodeModuleConfig); err != nil {
			log.Fatalf("error: %v", err)
		}
		return
	}

	if o.DecodeData {
		if err := fkc.Decode(ctx, fkc.DecodeData); err != nil {
			log.Fatalf("error: %v", err)
		}
		return
	}

	if o.Address == "" {
		flag.Usage()
		os.Exit(2)
	}

	device := &fkc.DeviceClient{
		Address: o.Address,
		Port:    o.Port,
		Callbacks: &fkc.LogJsonCallbacks{
			Save: o.Save,
		},
		HexEncode: o.HexEncode,
	}

	if o.Status {
		_, err := device.QueryStatus()
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.Name != "" {
		_, err := device.ConfigureName(o.Name)
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.GetReadings {
		_, err := device.QueryGetReadings()
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.TakeReadings {
		_, err := device.QueryTakeReadings()
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.StartRecording {
		_, err := device.QueryStartRecording()
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.StopRecording {
		_, err := device.QueryStopRecording()
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.ScanModules {
		_, err := device.QueryScanModules()
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if len(o.List) != 0 {
		_, err := device.QueryListing(o.List, uint32(o.Skip))
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.ScanNetworks {
		_, err := device.QueryScanNetworks()
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.LoraClear {
		_, err := device.ClearLora()
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.LoraDeviceEui != "" && o.LoraAppKey != "" && o.LoraJoinEui != "" {
		_, err := device.ConfigureLoraOtaa(o.LoraDeviceEui, o.LoraAppKey, o.LoraJoinEui, o.LoraFrequencyBand)
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.LoraAppSessionKey != "" && o.LoraNetworkSessionKey != "" && o.LoraDeviceAddress != "" {
		_, err := device.ConfigureLoraAbp(o.LoraAppSessionKey, o.LoraNetworkSessionKey, o.LoraDeviceAddress,
			uint32(o.LoraUplinkCounter), uint32(o.LoraDownlinkCounter), uint32(o.LoraFrequencyBand))
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.Schedule != "" {
		f := strings.Split(o.Schedule, ",")
		if len(f) == 4 {
			readings, _ := strconv.Atoi(f[0])
			network, _ := strconv.Atoi(f[1])
			gps, _ := strconv.Atoi(f[2])
			lora, _ := strconv.Atoi(f[3])
			_, err := device.ConfigureSchedule(uint32(readings), uint32(network), uint32(gps), uint32(lora))
			if err != nil {
				log.Fatalf("error: %v", err)
			}
		}
	}

	if o.Wifi != "" {
		networks := buildNetworks(o.Wifi)
		_, err := device.ConfigureWifiNetworks(networks)
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.FactoryReset {
		_, err := device.FactoryReset()
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.TransmissionUrl != "" || o.TransmissionToken != "" {
		_, err := device.ConfigureTransmission(o.TransmissionUrl, o.TransmissionToken)
		if err != nil {
			log.Fatalf("error: %v", err)
		}
	}

	if o.ConfigureModule >= 0 {
		err := configureModule(device, uint32(o.ConfigureModule), 1, 0)
		if err != nil {
			panic(err)
		}
	}

	if o.ResetModule >= 0 {
		err := resetModule(device, uint32(o.ResetModule))
		if err != nil {
			panic(err)
		}
	}

	if o.Module >= 0 {
		err := queryModuleStatus(device, uint32(o.Module))
		if err != nil {
			panic(err)
		}
	}
}

func buildNetworks(wifi string) []*pbapp.NetworkInfo {
	networks := make([]*pbapp.NetworkInfo, 0)
	parts := strings.Split(wifi, ",")
	if len(parts)%2 != 0 {
		return networks
	}

	for i := 0; i < len(parts); {
		networks = append(networks, &pbapp.NetworkInfo{
			Ssid:     parts[i],
			Password: parts[i+1],
		})
		i += 2
	}

	return networks
}

func queryModuleStatus(device *fkc.DeviceClient, module uint32) (err error) {
	moduleQuery := &pbapp.ModuleHttpQuery{
		Type: pbapp.ModuleQueryType_MODULE_QUERY_STATUS,
	}

	log.Printf("query: %v", moduleQuery)

	rawQuery, err := proto.Marshal(moduleQuery)
	if err != nil {
		return err
	}

	rawReply, err := device.ModuleQuery(module, rawQuery)
	if err != nil {
		return err
	}

	log.Printf("reply: %v", rawReply)

	reply := &pbapp.ModuleHttpReply{}
	buffer := proto.NewBuffer(rawReply)

	err = buffer.DecodeMessage(reply)
	if err != nil {
		return err
	}

	log.Printf("reply: %v", reply)

	return nil
}

func configureModule(device *fkc.DeviceClient, module uint32, m, b float32) (err error) {
	calibration := &pbdata.ModuleConfiguration{
		Calibration: &pbdata.Calibration{
			Type: pbdata.CurveType_CURVE_LINEAR,
			Time: 0,
			Points: []*pbdata.CalibrationPoint{
				&pbdata.CalibrationPoint{
					References:   []float32{1},
					Uncalibrated: []float32{1},
					Factory:      []float32{1},
				},
				&pbdata.CalibrationPoint{
					References:   []float32{2},
					Uncalibrated: []float32{2},
					Factory:      []float32{2},
				},
				&pbdata.CalibrationPoint{
					References:   []float32{3},
					Uncalibrated: []float32{3},
					Factory:      []float32{3},
				},
			},
			Coefficients: &pbdata.CalibrationCoefficients{
				Values: []float32{0.0, 1.0},
			},
		},
	}

	configurationData, err := proto.Marshal(calibration)
	if err != nil {
		return err
	}

	configurationDelimited := proto.NewBuffer(make([]byte, 0))
	configurationDelimited.EncodeRawBytes(configurationData)

	log.Printf("configuration: %v", configurationDelimited.Bytes())

	moduleQuery := &pbapp.ModuleHttpQuery{
		Type:          pbapp.ModuleQueryType_MODULE_QUERY_CONFIGURE,
		Configuration: configurationDelimited.Bytes(),
	}

	log.Printf("query: %v", moduleQuery)

	rawQuery, err := proto.Marshal(moduleQuery)
	if err != nil {
		return err
	}

	rawReply, err := device.ModuleQuery(module, rawQuery)
	if err != nil {
		return err
	}

	log.Printf("reply: %v", rawReply)

	reply := &pbapp.ModuleHttpReply{}
	buffer := proto.NewBuffer(rawReply)

	err = buffer.DecodeMessage(reply)
	if err != nil {
		return err
	}

	log.Printf("reply: %v", reply)

	return
}

func resetModule(device *fkc.DeviceClient, module uint32) (err error) {
	moduleQuery := &pbapp.ModuleHttpQuery{
		Type: pbapp.ModuleQueryType_MODULE_QUERY_RESET,
	}

	log.Printf("query: %v", moduleQuery)

	rawQuery, err := proto.Marshal(moduleQuery)
	if err != nil {
		return err
	}

	rawReply, err := device.ModuleQuery(module, rawQuery)
	if err != nil {
		return err
	}

	log.Printf("reply: %v", rawReply)

	reply := &pbapp.ModuleHttpReply{}
	buffer := proto.NewBuffer(rawReply)

	err = buffer.DecodeMessage(reply)
	if err != nil {
		return err
	}

	log.Printf("reply: %v", reply)

	return
}
