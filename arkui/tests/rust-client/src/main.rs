use std::time::Duration;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let url = std::env::args().nth(1).expect("URL required");
    let upload = std::env::args().any(|value| value == "--upload");
    let mut builder = reqwest::Client::builder();
    if !std::env::args().any(|value| value == "--system-proxy") { builder = builder.no_proxy(); }
    let client = builder
        .danger_accept_invalid_certs(true)
        .timeout(Duration::from_secs(if upload { 90 } else { 8 })).build()?;
    if upload {
        let args: Vec<String> = std::env::args().collect();
        let mib: usize = args.iter().position(|value| value == "--mib")
            .and_then(|index| args.get(index + 1)).map(|value| value.parse()).transpose()?.unwrap_or(8);
        if mib == 0 || mib > 1024 { return Err("Probe size must be 1–1024 MiB".into()); }
        let size = mib * 1024 * 1024;
        let offer = serde_json::json!({
            "info": { "alias": "HTTPS 互通自检", "version": "2.1", "deviceModel": "Rust reqwest", "deviceType": "desktop",
                "fingerprint": "", "port": 53318, "protocol": "http", "download": false },
            "files": { "probe": { "id": "probe", "fileName": format!("AloeSend-HTTPS-probe-{mib}MiB.bin"), "fileType": "application/octet-stream", "size": size } }
        });
        println!("Sending receive request; waiting for consent");
        let response = client.post(format!("{url}/api/localsend/v2/prepare-upload"))
            .header("content-type", "application/json").body(offer.to_string()).send().await?;
        let status = response.status(); let body = response.bytes().await?;
        println!("Prepare response: {status}, {} bytes", body.len());
        if !status.is_success() { return Err(format!("Prepare rejected: {status}").into()); }
        let prepared: serde_json::Value = serde_json::from_slice(&body)?;
        let session = prepared["sessionId"].as_str().ok_or("No session ID")?;
        let token = prepared["files"]["probe"].as_str().ok_or("No upload token")?;
        println!("Opening HTTPS file upload, {mib} MiB, streamed 64 KiB chunks");
        let stream = futures_util::stream::unfold(0usize, move |offset| async move {
            if offset >= size { None } else { let length = (size - offset).min(65536);
                Some((Ok::<_, std::io::Error>(vec![0x53u8; length]), offset + length)) }
        });
        let response = client.post(format!("{url}/api/localsend/v2/upload"))
            .query(&[("sessionId", session), ("fileId", "probe"), ("token", token)])
            .header("content-length", size).body(reqwest::Body::wrap_stream(stream)).send().await?;
        let status = response.status(); let body = response.bytes().await?;
        println!("Upload response: {status}, {} bytes", body.len());
        if !status.is_success() { return Err(format!("Upload rejected: {status}").into()); }
        return Ok(());
    }
    for index in 0..5 {
        let response = client.get(&url).send().await?;
        let status = response.status();
        let bytes = response.bytes().await?;
        println!("Rust reqwest request {index}: {status}, {} bytes", bytes.len());
    }
    Ok(())
}
