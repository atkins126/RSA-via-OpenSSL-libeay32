{****************************************************
Copyright (C) 2015, Ivan Lodyanoy
ddlencemc@gmail.com

uses libeay32 - Copyright (C) 2002-2010, Marco Ferrante.


  12.Dec.2022 - improving memory management
                Jacek Mulawka j.mulawka@interia.pl https://github.com/jacek-mulawka/
}

unit RSAOpenSSL;
interface
uses
  SysUtils, Dialogs, Classes, Controls, StdCtrls, libeay32;

{$IF CompilerVersion <= 14.0}   // Delphi 7
type
  TRSAData = packed record
    DecryptedData: string;
    EncryptedData: string;
    ErrorResult: integer;
    ErrorMessage: string;
  end;
{$EndIf}
{$IF CompilerVersion > 14.0}    // Other
type
  TRSAData = packed record
    DecryptedData: Ansistring;
    EncryptedData: Ansistring;
    ErrorResult: integer;
    ErrorMessage: string;
  end;
{$EndIf}

type
  TRSAOpenSSL = class
  private
    FPublicKey: pEVP_PKEY;
    FPrivateKey: pEVP_PKEY;
    FCryptedBuffer: Pointer;

{$IF CompilerVersion <= 14.0}
    fPublicKeyPath: string;
    fPrivateKeyPath: string;
{$EndIf}
{$IF CompilerVersion > 14.0}
    fPublicKeyPath: Ansistring;
    fPrivateKeyPath: Ansistring;
{$EndIf}

    function LoadPrivateKey: pEVP_PKEY;
    function LoadPublicKey: pEVP_PKEY;

    procedure FreeSSL;
    procedure LoadSSL;
    function LoadPrivateKeyFromString: pEVP_PKEY;
  public
    constructor Create(aPathToPublickKey, aPathToPrivateKey: string); overload;
    destructor Destroy; override;
    procedure PublicEncrypt(var aRSAData: TRSAData);
    procedure PrivateDecrypt(var aRSAData: TRSAData);
    procedure PrivateEncrypt(var aRSAData: TRSAData);
    procedure PublicDecrypt(var aRSAData: TRSAData);
    function SHA1_base64(AData: string): string;
    function SHA1_Sign_PK(AData: string): string;
    function SHA1(AData: string): string;
    function SHA256(AData: string): string;
    function SHA512(AData: string): string;
    procedure GenerateKeyPair(aBits: Integer; out aPublicKey, aPrivateKey: string);
  end;

implementation

{ TRSAOpenSSL }

constructor TRSAOpenSSL.Create(aPathToPublickKey, aPathToPrivateKey: string);
begin
  inherited Create;

  OpenSSL_add_all_algorithms;
  OpenSSL_add_all_ciphers;
  OpenSSL_add_all_digests;
  ERR_load_crypto_strings;
  ERR_load_RSA_strings;
  fPublicKeyPath := aPathToPublickKey;
  fPrivateKeyPath := aPathToPrivateKey
  {
  with aRSAKeys do
  begin
    ErrorResult := 0;
    ErrorMessage:= '';

    if PathToPublickKey <> '' then
    begin
      FPublicKey := LoadPublicKey(PathToPublickKey);
      if FPublicKey = nil then
      begin
        ErrorResult := -1;
        err := ERR_get_error;
        repeat
          ErrorMessage := ErrorMessage + string(ERR_error_string(err, nil)) + #10;
          err := ERR_get_error;
        until err = 0;
      end
      else
        ErrorMessage := ErrorMessage + 'Publick Key Stored' + #10;
    end;

    if PathToPrivateKey <> '' then
    begin
      FPrivateKey := LoadPrivateKey(PathToPrivateKey);
      if FPrivateKey = nil then
      begin
        ErrorResult := -1;
        err := ERR_get_error;
        repeat
          ErrorMessage := ErrorMessage + string(ERR_error_string(err, nil)) + #10;
          err := ERR_get_error;
        until err = 0;
      end
      else
        ErrorMessage := ErrorMessage + 'Private Key Stored' + #10;
    end;
  end;
  }
end;


destructor TRSAOpenSSL.Destroy;
begin
  EVP_cleanup;
  ERR_free_strings;

  if FPublicKey <> nil then
    EVP_PKEY_free(FPublicKey);
  if FPrivateKey <> nil then
    EVP_PKEY_free(FPrivateKey);

  inherited;
end;


function TRSAOpenSSL.LoadPublicKey: pEVP_PKEY;
var
  mem: pBIO;
  k: pEVP_PKEY;
begin
  k:=nil;
  mem := BIO_new(BIO_s_file);
  BIO_read_filename(mem, PAnsiChar(fPublicKeyPath));
  try
    result := PEM_read_bio_PUBKEY(mem, k, nil, nil);
  finally
    BIO_free_all(mem);
  end;
end;


function TRSAOpenSSL.LoadPrivateKey: pEVP_PKEY;
var
  mem: pBIO;
  k: pEVP_PKEY;
begin
  k := nil;
  mem := BIO_new(BIO_s_file);
  BIO_read_filename(mem, PAnsiChar(fPrivateKeyPath));
  try
    result := PEM_read_bio_PrivateKey(mem, k, nil, nil);
  finally
    BIO_free_all(mem);
  end;
end;


function TRSAOpenSSL.LoadPrivateKeyFromString: pEVP_PKEY;
var
  mem, keybio: pBIO;
  k: pEVP_PKEY;
  keystring: AnsiString;
begin
  keystring :=
  '-----BEGIN RSA PRIVATE KEY-----' + #10 +
  'MIICXgIBAAKBgQCfydli2u2kJfb2WetkOekjzQIg7bIuU7AzAlBUPuA72UYXWnQ/' + #10 +
  'XcdSzEEMWSBLP7FO1vyVXR4Eb0/WqthF0ZViOK5bCN9CnR/1GMMiSqmIdByv/gUe' + #10 +
  'Z/UjGrKmxeQOoa2Yt0MJC64cNXgnKmYC7ui3A12LlvNdBBEF3WpcDbv+PQIDAQAB' + #10 +
  'AoGBAJnxukKHchSHjxthHmv9byRSyw42c0g20LcUL5g6y4Zdmi29s+moy/R1XOYs' + #10 +
  'p/RXdNfkQI0WnWjgZScIij0Z4rSs39uh7eQ5qxK+NH3QIWeR2ZNIno9jAXPn2bkQ' + #10 +
  'odS8FPzbZM9wHhpRvKW4FNPXqTc3ZkTcxi4zOwOdlECf9G+BAkEAzsJHgW1Isyac' + #10 +
  'I61MDu2qjMUwOdOBYS8GwEBfi/vbn/duwZIBXG/BZ7Pn+cBwImfksEXwx0MTkgF3' + #10 +
  'gyaChUSu+QJBAMXX3d94TwcF7lG9zkzc+AR/Onl4Z5UAb1GmUV57oYIFVgW1RIOk' + #10 +
  'vqynXWrTjTOg9C9j+VEpBG67LcnkwU16JmUCQH7pukKz9kAhnw43PcycDmhCUgvs' + #10 +
  'zCn/V8GCwiOHAZT7qLyhBrzazHj/cZFYknxMEZAyHk3x2n1w8Q9MACoVsuECQQDF' + #10 +
  'U7cyara31IyM7vlS5JpjMdrKyPLXRKXDFFXYHQtLubLA4rlBbBHZ9txP7kzJj+G9' + #10 +
  'WsOS1YxcPUlAM28xrYGZAkEArVKJHX4dF8UUtfvyv78muXJZNXTwmaaFy02xjtR5' + #10 +
  'uXWT1QjVN2a6jv6AW7ukXiSoE/spgfvdoriMk2JSs88nUw==' + #10 +
  '-----END RSA PRIVATE KEY-----' ;
  k := nil;


  keybio := BIO_new_mem_buf(Pchar(keystring), -1);
  mem := BIO_new(BIO_s_mem);
  BIO_read(mem, PAnsiChar(keystring), length(PAnsiChar(keystring)));

  try
    result := PEM_read_bio_PrivateKey(keybio, k, nil, nil);
  finally
    BIO_free_all(mem);
  end;
end;


procedure TRSAOpenSSL.PublicEncrypt(var aRSAData: TRSAData);
var
  rsa: pRSA;
  str, data: AnsiString;
  len, b64len: Integer;
  penc64: PAnsiChar;
  b64, mem: pBIO;
  size: Integer;
  err: Cardinal;
begin
  LoadSSL;
  FPublicKey := LoadPublicKey;

  if FPublicKey = nil then
  begin
    err := ERR_get_error;
    repeat
      aRSAData.ErrorMessage := aRSAData.ErrorMessage + string(ERR_error_string(err, nil)) + #10;
      err := ERR_get_error;
    until err = 0;
    exit;
  end;

  rsa := EVP_PKEY_get1_RSA(FPublicKey);
  EVP_PKEY_free(FPublicKey);
  FPublicKey := nil; // Jacek Mulawka (12.Dec.2022).

  size := RSA_size(rsa);

  GetMem(FCryptedBuffer, size);
  str := AnsiString(aRSAData.DecryptedData);

  len := RSA_public_encrypt(Length(str), PAnsiChar(str), FCryptedBuffer, rsa, RSA_PKCS1_PADDING);

  if len > 0 then
  begin
    aRSAData.ErrorResult := 0;
    //create a base64 BIO
    b64 := BIO_new(BIO_f_base64);
    mem := BIO_push(b64, BIO_new(BIO_s_mem));
    try
      //encode data to base64
      BIO_write(mem, FCryptedBuffer, len);
      BIO_flush(mem);
      b64len := BIO_get_mem_data(mem, penc64);

      //copy data to string
      SetLength(data, b64len);
      Move(penc64^, PAnsiChar(data)^, b64len);
      aRSAData.ErrorMessage := 'String has been encrypted, then base64 encoded.' + #10;
      aRSAData.EncryptedData := string(data);
    finally
      BIO_free_all(mem);
    end;
  end
  else
  begin
    err := ERR_get_error;
    aRSAData.ErrorResult := -1;
    repeat
      aRSAData.ErrorMessage := aRSAData.ErrorMessage + string(ERR_error_string(err, nil)) + #10;
      err := ERR_get_error;
    until err = 0;
  end;
  FreeMem( FCryptedBuffer ); // Jacek Mulawka (12.Dec.2022).
  RSA_free(rsa);
  FreeSSL;
end;


procedure TRSAOpenSSL.PrivateDecrypt(var aRSAData: TRSAData);
var
  rsa: pRSA;
  out_: AnsiString;
  str, data: PAnsiChar;
  len: Integer;
  b64, mem: pBIO;
  size: Integer;
  err: Cardinal;
begin
  LoadSSL;
  FPrivateKey := LoadPrivateKey;
  //FPrivateKey := LoadPrivateKeyFromString(''); // Load PrivateKey from including ansistring;
  if FPrivateKey = nil then
  begin
    err := ERR_get_error;
    repeat
      aRSAData.ErrorMessage:= aRSAData.ErrorMessage + string(ERR_error_string(err, nil)) + #10;
      err := ERR_get_error;
    until err = 0;
    exit;
  end;
  rsa := EVP_PKEY_get1_RSA(FPrivateKey);
  size := RSA_size(rsa);

  GetMem(data, size);
  GetMem(str, size);

  b64 := BIO_new(BIO_f_base64);
  mem := BIO_new_mem_buf(PAnsiChar(aRSAData.EncryptedData), Length(aRSAData.EncryptedData));
  BIO_flush(mem);
  mem := BIO_push(b64, mem);
  BIO_read(mem, str , Length(aRSAData.EncryptedData));
  BIO_free_all(mem);

  len := RSA_private_decrypt(size, PAnsiChar(str), data, rsa, RSA_PKCS1_PADDING);

  if len > 0 then
  begin
    SetLength(out_, len);
    Move(data^, PAnsiChar(out_ )^, len);
    aRSAData.ErrorResult := 0;
    aRSAData.ErrorMessage := 'Base64 has been decoded and decrypted' + #10;
    aRSAData.DecryptedData := out_;
  end
  else
  begin
    err := ERR_get_error;
    aRSAData.ErrorResult := -1;
    repeat
      aRSAData.ErrorMessage := aRSAData.ErrorMessage + string(ERR_error_string(err, nil)) + #10;
      err := ERR_get_error;
    until err = 0;
  end;
  FreeMem( data ); // Jacek Mulawka (12.Dec.2022).
  FreeMem( str ); // Jacek Mulawka (12.Dec.2022).
  RSA_free(rsa);
  FreeSSL;
end;


procedure TRSAOpenSSL.PrivateEncrypt(var aRSAData: TRSAData);
var
  rsa: pRSA;
  str, data: AnsiString;
  len, b64len: Integer;
  penc64: PAnsiChar;
  b64, mem: pBIO;
  size: Integer;
  err: Cardinal;
begin
  LoadSSL;
  FPrivateKey := LoadPrivateKey;

  if FPrivateKey = nil then
  begin
    err := ERR_get_error;
    repeat
      aRSAData.ErrorMessage := aRSAData.ErrorMessage + string(ERR_error_string(err, nil)) + #10;
      err := ERR_get_error;
    until err = 0;
    exit;
  end;

  rsa := EVP_PKEY_get1_RSA(FPrivateKey);
  EVP_PKEY_free(FPrivateKey);
  FPrivateKey := nil; // Jacek Mulawka (12.Dec.2022).

  size := RSA_size(rsa);

  GetMem(FCryptedBuffer, size);
  str := AnsiString(aRSAData.DecryptedData);

  len := RSA_private_encrypt(Length(str), PAnsiChar(str), FCryptedBuffer, rsa, RSA_PKCS1_PADDING);

  if len > 0 then
  begin
    aRSAData.ErrorResult := 0;
    //create a base64 BIO
    b64 := BIO_new(BIO_f_base64);
    mem := BIO_push(b64, BIO_new(BIO_s_mem));
    try
      //encode data to base64
      BIO_write(mem, FCryptedBuffer, len);
      BIO_flush(mem);
      b64len := BIO_get_mem_data(mem, penc64);

      //copy data to string
      SetLength(data, b64len);
      Move(penc64^, PAnsiChar(data)^, b64len);
      aRSAData.ErrorMessage := 'String has been encrypted, then base64 encoded.' + #10;
      aRSAData.EncryptedData := string(data);
    finally
      BIO_free_all(mem);
    end;
  end
  else
  begin
    err := ERR_get_error;
    aRSAData.ErrorResult := -1;
    repeat
      aRSAData.ErrorMessage := aRSAData.ErrorMessage + string(ERR_error_string(err, nil)) + #10;
      err := ERR_get_error;
    until err = 0;
  end;
  FreeMem( FCryptedBuffer ); // Jacek Mulawka (12.Dec.2022).
  RSA_free(rsa);
end;


procedure TRSAOpenSSL.PublicDecrypt(var aRSAData: TRSAData);
var
  rsa: pRSA;
  out_: AnsiString;
  str, data: PAnsiChar;
  len: Integer;
  b64, mem: pBIO;
  size: Integer;
  err: Cardinal;
begin
  LoadSSL;
  FPublicKey := LoadPublicKey;

  if FPublicKey = nil then
  begin
    err := ERR_get_error;
    repeat
      aRSAData.ErrorMessage := aRSAData.ErrorMessage + string(ERR_error_string(err, nil)) + #10;
      err := ERR_get_error;
    until err = 0;
    exit;
  end;

  rsa := EVP_PKEY_get1_RSA(FPublicKey);
  size := RSA_size(rsa);

  GetMem(data, size);
  GetMem(str, size);

  b64 := BIO_new(BIO_f_base64);
  mem := BIO_new_mem_buf(PAnsiChar(aRSAData.EncryptedData), Length(aRSAData.EncryptedData));
  BIO_flush(mem);
  mem := BIO_push(b64, mem);
  BIO_read(mem, str , Length(aRSAData.EncryptedData));
  BIO_free_all(mem);

  len := RSA_public_decrypt(size, PAnsiChar(str), data, rsa, RSA_PKCS1_PADDING);

  if len > 0 then
  begin
    SetLength(out_, len);
    Move(data^, PAnsiChar(out_ )^, len);
    aRSAData.ErrorResult := 0;
    aRSAData.ErrorMessage := 'Base64 has been decoded and decrypted' + #10;
    aRSAData.DecryptedData := out_;
  end
  else
  begin
    err := ERR_get_error;
    aRSAData.ErrorResult := -1;
    repeat
      aRSAData.ErrorMessage := aRSAData.ErrorMessage + string(ERR_error_string(err, nil)) + #10;
      err := ERR_get_error;
    until err = 0;
  end;
  FreeMem( data ); // Jacek Mulawka (12.Dec.2022).
  FreeMem( str ); // Jacek Mulawka (12.Dec.2022).
  RSA_free(rsa);
end;


function TRSAOpenSSL.SHA1_base64(AData: string): string;
var
  b64Length: integer;
  mdLength: cardinal;
  mdValue: array [0..EVP_MAX_MD_SIZE] of byte;
  mdctx: EVP_MD_CTX;
  memout, b64: pBIO;
  inbuf, outbuf: array [0..1023] of char;
begin
  StrPCopy(inbuf, AData);
  EVP_DigestInit(@mdctx, EVP_sha1);
  EVP_DigestUpdate(@mdctx, @inbuf, StrLen(inbuf));
  EVP_DigestFinal(@mdctx, @mdValue, mdLength);

  b64 := BIO_new(BIO_f_base64);
  memout := BIO_new(BIO_s_mem);
  b64 := BIO_push(b64, memout);
  BIO_write(b64, @mdValue, mdLength);
  BIO_flush(b64);
  b64Length := BIO_read(memout, @outbuf, 1024);
  outbuf[b64Length-1] := #0;
  result := StrPas(outbuf);
end;


function TRSAOpenSSL.SHA1(AData: string): string;
var
  Len: cardinal;
  mdctx: EVP_MD_CTX;
  inbuf, outbuf: array [0..1023] of char;
begin
  StrPCopy(inbuf, AData);
  LoadSSL;

  EVP_DigestInit(@mdctx, EVP_sha1);
  EVP_DigestUpdate(@mdctx, @inbuf, StrLen(inbuf));
  EVP_DigestFinal(@mdctx, @outbuf, Len);

  FreeSSL;
  BinToHex(outbuf, inbuf,Len);
  inbuf[2*Len] := #0;
  result := StrPas(inbuf);
end;

function TRSAOpenSSL.SHA256(AData: string): string;
var
  Len: cardinal;
  mdctx: EVP_MD_CTX;
  inbuf, outbuf: array [0..1023] of char;
begin
  StrPCopy(inbuf, AData);
  LoadSSL;

  EVP_DigestInit(@mdctx, EVP_sha256);
  EVP_DigestUpdate(@mdctx, @inbuf, StrLen(inbuf));
  EVP_DigestFinal(@mdctx, @outbuf, Len);

  FreeSSL;
  BinToHex(outbuf, inbuf,Len);
  inbuf[2*Len] := #0;
  result := StrPas(inbuf);
end;


function TRSAOpenSSL.SHA512(AData: string): string;
var
  Len: cardinal;
  mdctx: EVP_MD_CTX;
  inbuf, outbuf: array [0..1023] of char;
begin
  StrPCopy(inbuf, AData);
  LoadSSL;

  EVP_DigestInit(@mdctx, EVP_sha512);
  EVP_DigestUpdate(@mdctx, @inbuf, StrLen(inbuf));
  EVP_DigestFinal(@mdctx, @outbuf, Len);

  FreeSSL;
  BinToHex(outbuf, inbuf,Len);
  inbuf[2*Len] := #0;
  result := StrPas(inbuf);
end;


function TRSAOpenSSL.SHA1_Sign_PK(AData: string): string;
var
  Len: cardinal;
  mdctx: EVP_MD_CTX;
  inbuf, outbuf: array [0..1023] of char;
  key: pEVP_PKEY;
begin
  StrPCopy(inbuf, AData);
  LoadSSL;

  key := LoadPrivateKeyFromString;
  EVP_SignInit(@mdctx, EVP_sha1);
  EVP_SignUpdate(@mdctx, @inbuf, StrLen(inbuf));
  EVP_SignFinal(@mdctx, @outbuf, Len, key);

  FreeSSL;
  BinToHex(outbuf, inbuf,Len);
  inbuf[2*Len] := #0;
  result := StrPas(inbuf);
end;


procedure TRSAOpenSSL.LoadSSL;
begin
  OpenSSL_add_all_algorithms;
  OpenSSL_add_all_ciphers;
  OpenSSL_add_all_digests;
  ERR_load_crypto_strings;
  ERR_load_RSA_strings;
end;


procedure TRSAOpenSSL.FreeSSL;
begin
  EVP_cleanup;
  ERR_free_strings;
end;


procedure TRSAOpenSSL.GenerateKeyPair(aBits: Integer; out aPublicKey, aPrivateKey: string);
var
  bne: pBIGNUM;
  rsa: pRSA;
  ret: Integer;
  publicBio: pBIO;
  privateBio: pBIO;
  buf: TBytes;
  len: Integer;
  pk: pEVP_PKEY;
begin
  aPublicKey := '';
  aPrivateKey := '';

  // Prepare BIGNUM
  bne := BN_new;
  ret := BN_set_word(bne, RSA_F4);
  if ret = 0 then
    raise Exception.Create('Failed to create pBIGNUM');

  // Generate the key
  rsa := RSA_new;
  ret := RSA_generate_key_ex(rsa, aBits, bne, nil);
  if ret = 0 then
    raise Exception.Create('Failed to generate RSA key');

  // Convert RSA to PKEY (so we can save it in non-RSA format that everyone prefers?)
  pk := EVP_PKEY_new;
  ret := EVP_PKEY_assign(pk, EVP_PKEY_RSA, rsa);
  if ret = 0 then
    raise Exception.Create('Failed to EVP_PKEY_assign_RSA');

  // Get the public key
  publicBio := BIO_new(BIO_s_mem);
  try
    //ret := PEM_write_bio_RSAPublicKey(publicBio, rsa); // RSA format
    ret := PEM_write_bio_PUBKEY(publicBio, pk); // PKEY format
    if ret = 0 then
      raise Exception.Create('Failed to PEM_write_bio_PUBKEY');

    len := BIO_pending(publicBio);

    SetLength(buf, len);
    ret := BIO_read(publicBio, buf, len);
    if ret <= 0 then
      raise Exception.Create('Failed to BIO_read');

    aPublicKey := StringOf(buf);
  finally
    if Assigned(publicBio) then
      BIO_free(publicBio);
  end;

  // Get the private key
  privateBio := BIO_new(BIO_s_mem);
  try
    //ret := PEM_write_bio_RSAPrivateKey(privateBio, rsa, nil, nil, 0, nil, nil); // RSA format
    ret := PEM_write_bio_PrivateKey(privateBio, pk, nil, nil, 0, nil, nil); // PKEY format
    if ret = 0 then
      raise Exception.Create('Failed to PEM_write_bio_PrivateKey');

    len := BIO_pending(privateBio);

    SetLength(buf, len);
    ret := BIO_read(privateBio, buf, len);
    if ret <= 0 then
      raise Exception.Create('Failed to BIO_read');

    aPrivateKey := StringOf(buf);
  finally
    if Assigned(publicBio) then
      BIO_free(privateBio);
  end;

{  // Just in case we can save keys directly and compare them for differences
  // save public key file
  publicBio := BIO_new_file(PAnsiChar('public_.pem'), PAnsiChar('w+'));
  //ret := PEM_write_bio_RSAPublicKey(publicBio, rsa); // RSA format
  ret := PEM_write_bio_PUBKEY(publicBio, pk); // PKEY format
  if ret = 0 then
    raise Exception.Create('Failed to save public key file');

  if Assigned(publicBio) then
    BIO_free(publicBio);

  // save private key file
  privateBIO := BIO_new_file(PAnsiChar('private_.pem'), PAnsiChar('w+'));
  //ret := PEM_write_bio_RSAPrivateKey(privateBIO, rsa, nil, nil, 0, nil, nil); // RSA format
  ret := PEM_write_bio_PrivateKey(privateBIO, pk, nil, nil, 0, nil, nil); // PKEY format
  if ret = 0 then
    raise Exception.Create('Failed to save private key file');

  if Assigned(privateBio) then
    BIO_free(privateBio);}

  if Assigned(Bne) then
    BN_free(Bne);

  // Ownership of the key assigned via the EVP_PKEY_assign_RSA call is transferred to the EVP_PKEY
  // When you free the EVP_PKEY it also frees the underlying RSA key
  if Assigned(pk) then
    EVP_PKEY_free(pk);
end;


end.
