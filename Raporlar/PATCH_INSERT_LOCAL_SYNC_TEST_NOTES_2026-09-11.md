# Regression Notes

CI bu parti için şu sözleşmeleri korumalıdır:

- static catalog metadata resolution placeholder üretmemeli,
- factory/mine/field/farm kendi type kataloğunu kullanmalı,
- eksik metadata `null` dönmeli ve targeted refresh fallback'ine bırakılmalı,
- production building insert service derlenebilir olmalı.
