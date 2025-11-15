package fkdevice

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/golang/protobuf/proto"
	"github.com/robinpowered/go-proto/message"
	"github.com/robinpowered/go-proto/stream"

	pbapp "gitlab.com/fieldkit/libraries/app-protocol"
	pbdata "gitlab.com/fieldkit/libraries/data-protocol"
)

type DecodeFunction func(ctx context.Context, b []byte) error

func DecodeApp(ctx context.Context, b []byte) error {
	var reply pbapp.HttpReply
	err := proto.Unmarshal(b, &reply)
	if err != nil {
		return err
	}

	replyJson, err := json.MarshalIndent(reply, "", "  ")
	if err == nil {
		fmt.Println(string(replyJson))
	}

	return nil
}

func DecodeModuleConfig(ctx context.Context, b []byte) error {
	var reply pbdata.ModuleConfiguration
	err := proto.Unmarshal(b, &reply)
	if err != nil {
		return err
	}

	replyJson, err := json.MarshalIndent(reply, "", "  ")
	if err == nil {
		fmt.Println(string(replyJson))
	}

	return nil
}

func DecodeData(ctx context.Context, b []byte) error {
	var reply pbdata.DataRecord
	err := proto.Unmarshal(b, &reply)
	if err != nil {
		return err
	}

	replyJson, err := json.MarshalIndent(reply, "", "  ")
	if err == nil {
		fmt.Println(string(replyJson))
	}

	return nil
}

func Decode(ctx context.Context, decode DecodeFunction) error {
	unmarshalFunc := message.UnmarshalFunc(func(b []byte) (proto.Message, error) {
		return nil, decode(ctx, b)
	})

	_, err := stream.ReadLengthPrefixedCollection(os.Stdin, unmarshalFunc)
	if err != nil {
		return err
	}

	return nil
}
