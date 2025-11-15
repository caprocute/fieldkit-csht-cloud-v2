package main

import "math/rand"

// VietnamStation chứa thông tin về một station ở Việt Nam
type VietnamStation struct {
	Name      string
	Longitude float64
	Latitude  float64
	Province  string
	Region    string
}

// VietnamStations là danh sách các địa điểm ở Việt Nam có thể dùng cho FloodNet stations
var VietnamStations = []VietnamStation{
	// Hà Nội
	{"Hồ Hoàn Kiếm", 105.8412, 21.0285, "Hà Nội", "Miền Bắc"},
	{"Quận Ba Đình", 105.8342, 21.0245, "Hà Nội", "Miền Bắc"},
	{"Quận Đống Đa", 105.8482, 21.0325, "Hà Nội", "Miền Bắc"},
	{"Quận Hai Bà Trưng", 105.8552, 21.0205, "Hà Nội", "Miền Bắc"},
	{"Quận Tây Hồ", 105.8302, 21.0365, "Hà Nội", "Miền Bắc"},
	{"Quận Cầu Giấy", 105.8002, 21.0305, "Hà Nội", "Miền Bắc"},
	{"Quận Hoàn Kiếm", 105.8502, 21.0255, "Hà Nội", "Miền Bắc"},
	{"Quận Long Biên", 105.9002, 21.0405, "Hà Nội", "Miền Bắc"},

	// TP. Hồ Chí Minh
	{"Quận 1", 106.6297, 10.8231, "TP. Hồ Chí Minh", "Miền Nam"},
	{"Quận 3", 106.6800, 10.7833, "TP. Hồ Chí Minh", "Miền Nam"},
	{"Quận 7", 106.7167, 10.7333, "TP. Hồ Chí Minh", "Miền Nam"},
	{"Quận Bình Thạnh", 106.7000, 10.8000, "TP. Hồ Chí Minh", "Miền Nam"},
	{"Quận Tân Bình", 106.6500, 10.7833, "TP. Hồ Chí Minh", "Miền Nam"},
	{"Quận Phú Nhuận", 106.6833, 10.8000, "TP. Hồ Chí Minh", "Miền Nam"},
	{"Quận Gò Vấp", 106.6667, 10.8500, "TP. Hồ Chí Minh", "Miền Nam"},
	{"Quận Thủ Đức", 106.7500, 10.8500, "TP. Hồ Chí Minh", "Miền Nam"},

	// Đà Nẵng
	{"Quận Hải Châu", 108.2200, 16.0500, "Đà Nẵng", "Miền Trung"},
	{"Quận Thanh Khê", 108.2000, 16.0667, "Đà Nẵng", "Miền Trung"},
	{"Quận Sơn Trà", 108.2500, 16.1000, "Đà Nẵng", "Miền Trung"},
	{"Quận Ngũ Hành Sơn", 108.2667, 16.0167, "Đà Nẵng", "Miền Trung"},
	{"Quận Liên Chiểu", 108.1500, 16.0833, "Đà Nẵng", "Miền Trung"},

	// Hải Phòng
	{"Quận Hồng Bàng", 106.6833, 20.8667, "Hải Phòng", "Miền Bắc"},
	{"Quận Ngô Quyền", 106.7000, 20.8500, "Hải Phòng", "Miền Bắc"},
	{"Quận Lê Chân", 106.7167, 20.8333, "Hải Phòng", "Miền Bắc"},
	{"Quận Hải An", 106.7500, 20.8167, "Hải Phòng", "Miền Bắc"},

	// Cần Thơ
	{"Quận Ninh Kiều", 105.7833, 10.0333, "Cần Thơ", "Miền Nam"},
	{"Quận Bình Thủy", 105.7333, 10.0500, "Cần Thơ", "Miền Nam"},
	{"Quận Cái Răng", 105.7667, 10.0167, "Cần Thơ", "Miền Nam"},
	{"Quận Ô Môn", 105.8000, 10.0667, "Cần Thơ", "Miền Nam"},

	// An Giang
	{"Thành phố Long Xuyên", 105.4333, 10.3833, "An Giang", "Miền Nam"},
	{"Thị xã Châu Đốc", 105.1167, 10.7000, "An Giang", "Miền Nam"},

	// Đồng Tháp
	{"Thành phố Cao Lãnh", 105.6333, 10.4667, "Đồng Tháp", "Miền Nam"},
	{"Thành phố Sa Đéc", 105.7667, 10.3000, "Đồng Tháp", "Miền Nam"},

	// Kiên Giang
	{"Thành phố Rạch Giá", 105.0833, 10.0167, "Kiên Giang", "Miền Nam"},
	{"Thị xã Hà Tiên", 104.4833, 10.3833, "Kiên Giang", "Miền Nam"},

	// Bến Tre
	{"Thành phố Bến Tre", 106.3667, 10.2333, "Bến Tre", "Miền Nam"},
	{"Huyện Ba Tri", 106.5833, 10.0500, "Bến Tre", "Miền Nam"},

	// Tiền Giang
	{"Thành phố Mỹ Tho", 106.3500, 10.3500, "Tiền Giang", "Miền Nam"},
	{"Thị xã Gò Công", 106.6667, 10.3667, "Tiền Giang", "Miền Nam"},

	// Long An
	{"Thành phố Tân An", 106.4167, 10.5333, "Long An", "Miền Nam"},
	{"Huyện Cần Đước", 106.6667, 10.5000, "Long An", "Miền Nam"},

	// Bình Dương
	{"Thành phố Thủ Dầu Một", 106.6500, 10.9833, "Bình Dương", "Miền Nam"},
	{"Thị xã Dĩ An", 106.7667, 10.9167, "Bình Dương", "Miền Nam"},

	// Đồng Nai
	{"Thành phố Biên Hòa", 106.8167, 10.9500, "Đồng Nai", "Miền Nam"},
	{"Thành phố Long Khánh", 107.2333, 10.9333, "Đồng Nai", "Miền Nam"},

	// Bà Rịa - Vũng Tàu
	{"Thành phố Vũng Tàu", 107.2333, 10.3500, "Bà Rịa - Vũng Tàu", "Miền Nam"},
	{"Thành phố Bà Rịa", 107.1833, 10.5000, "Bà Rịa - Vũng Tàu", "Miền Nam"},

	// Huế
	{"Thành phố Huế", 107.6000, 16.4667, "Thừa Thiên Huế", "Miền Trung"},
	{"Huyện Phú Vang", 107.7000, 16.4000, "Thừa Thiên Huế", "Miền Trung"},

	// Quảng Nam
	{"Thành phố Hội An", 108.3333, 15.8833, "Quảng Nam", "Miền Trung"},
	{"Thành phố Tam Kỳ", 108.4833, 15.5667, "Quảng Nam", "Miền Trung"},

	// Quảng Ngãi
	{"Thành phố Quảng Ngãi", 108.8000, 15.1167, "Quảng Ngãi", "Miền Trung"},
	{"Huyện Bình Sơn", 108.7667, 15.2833, "Quảng Ngãi", "Miền Trung"},

	// Bình Định
	{"Thành phố Quy Nhon", 109.2167, 13.7667, "Bình Định", "Miền Trung"},
	{"Huyện Tuy Phước", 109.1500, 13.8333, "Bình Định", "Miền Trung"},

	// Phú Yên
	{"Thành phố Tuy Hòa", 109.3167, 13.0833, "Phú Yên", "Miền Trung"},
	{"Huyện Sông Cầu", 109.2167, 13.4500, "Phú Yên", "Miền Trung"},

	// Khánh Hòa
	{"Thành phố Nha Trang", 109.1833, 12.2500, "Khánh Hòa", "Miền Trung"},
	{"Thành phố Cam Ranh", 109.1500, 11.9167, "Khánh Hòa", "Miền Trung"},

	// Ninh Thuận
	{"Thành phố Phan Rang", 108.9833, 11.5667, "Ninh Thuận", "Miền Trung"},
	{"Huyện Ninh Hải", 109.0167, 11.6333, "Ninh Thuận", "Miền Trung"},

	// Bình Thuận
	{"Thành phố Phan Thiết", 108.1000, 10.9333, "Bình Thuận", "Miền Trung"},
	{"Huyện Tuy Phong", 108.7000, 11.3500, "Bình Thuận", "Miền Trung"},
}

// GetRandomStation trả về một station ngẫu nhiên từ danh sách
func GetRandomStation(rng *rand.Rand) VietnamStation {
	if rng == nil {
		rng = rand.New(rand.NewSource(rand.Int63()))
	}
	return VietnamStations[rng.Intn(len(VietnamStations))]
}

// GetRandomStations trả về n station ngẫu nhiên (có thể trùng)
func GetRandomStations(count int, rng *rand.Rand) []VietnamStation {
	if rng == nil {
		rng = rand.New(rand.NewSource(rand.Int63()))
	}
	stations := make([]VietnamStation, count)
	for i := 0; i < count; i++ {
		stations[i] = GetRandomStation(rng)
	}
	return stations
}

