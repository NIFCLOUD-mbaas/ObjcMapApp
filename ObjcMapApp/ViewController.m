//
//  ViewController.m
//  ObjcMapApp
//
//  Created by nifty on 2016/08/18.
//  Copyright © 2016年 NIFTY Corporation. All rights reserved.
//

#import "ViewController.h"
#import <NCMB/NCMB.h>
#import <GoogleMaps/GoogleMaps.h>

@interface ViewController ()<CLLocationManagerDelegate>
// Google Map
@property (weak,nonatomic) IBOutlet GMSMapView *mapView;
// TextField
@property (weak,nonatomic) IBOutlet UITextField *latTextField;
@property (weak,nonatomic) IBOutlet UITextField *lonTextField;
// Label
@property (weak,nonatomic) IBOutlet UILabel *label;
// 現在地
@property (nonatomic) CLLocation *myLocation;
@property (nonatomic) CLLocationManager *locationManager;
// マーカー
@property (nonatomic) GMSMarker *marker;
// mBaaSデータストア「Shop」クラスデータ格納用
@property (nonatomic) NSArray *shopData;

@end
// 新宿駅の位置情報
const CLLocationDegrees SHINJUKU_LAT = 35.690549;
const CGFloat SHINJUKU_LON = 139.699550;
// 西新宿駅の位置情報
const CGFloat WEST_SHINJUKU_LAT = 35.6945080;
const CGFloat WEST_SHINJUKU_LON = 139.692692;
// ニフティの位置情報
const CGFloat NIFTY_LAT = 35.696144;
const CGFloat NIFTY_LON = 139.689485;
// ズームレベル
const CGFloat ZOOM = 14.5;
// 検索範囲
static NSArray *SEAECH_RANGE = nil;


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 検索範囲
    SEAECH_RANGE = @[@"全件検索", @"現在地から半径5km以内を検索", @"現在地から半径1km以内を検索", @"新宿駅と西新宿駅の間を検索"];
    // 位置情報取得開始
    if ([CLLocationManager locationServicesEnabled]) {
        self.locationManager = [[CLLocationManager alloc]init];
        self.locationManager.delegate = self;
        [self.locationManager startUpdatingLocation];
    }
    
    // 起動時は新宿駅に設定
    [self showMap:SHINJUKU_LAT longitude:SHINJUKU_LON];
    [self addMarker:SHINJUKU_LAT longitude:SHINJUKU_LON title:@"新宿駅" snippet:@"Shinjuku Station" color:[UIColor greenColor]];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    // 位置情報取得の停止
    if ([CLLocationManager locationServicesEnabled]) {
        [self.locationManager stopUpdatingLocation];
    }
}

// 位置情報許可状況確認メソッド
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    switch (status) {
        case kCLAuthorizationStatusNotDetermined:
        // 初回のみ許可要求
        [self.locationManager requestWhenInUseAuthorization];
        break;
        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusDenied:
        // 位置情報許可を依頼するアラートの表示
        [self alertLocationServiceDisabled];
        break;
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
        break;
    }
}

// 位置情報許可依頼アラート
- (void)alertLocationServiceDisabled {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"位置情報が許可されていません"
                                                                   message:@"位置情報サービスを有効にしてください"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"設定"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * action) {
                                                NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                                                [[UIApplication sharedApplication]openURL:url];

                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"キャンセル"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction * action) {
                                                
                                            }]];
    [self presentViewController:alert animated:YES completion:nil];
}

// 位置情報が更新されるたびに呼ばれるメソッド
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    // 値をローカルに保存
    self.myLocation = [locations objectAtIndex:0];
    
    // TextFieldに表示
    self.latTextField.text = [NSString stringWithFormat:@"%.6f",self.myLocation.coordinate.latitude];
    self.lonTextField.text = [NSString stringWithFormat:@"%.6f",self.myLocation.coordinate.longitude];
    self.label.text = @"右上の「保存」をタップしてmBaaSに保存しよう！";
}

// 「保存」ボタン押下時の処理
- (void)saveLocation:(UIButton *)sender {
    // チェック
    if (!self.myLocation) {
        NSLog(@"位置情報が取得できていません");
        self.label.text = @"位置情報が取得できていません";
    } else {
        NSLog(@"位置情報が取得できました");
        self.label.text = @"位置情報が取得できました";
        
        // アラートを表示
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"現在地を保存します"
                                                                       message:@"情報を入力してください"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        // UIAlertControllerにtextFieldを2つ追加
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = @"タイトル";
        }];
        
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = @"コメント";
        }];
        // アラートの保存押下時の処理
        [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            // 入力値の取得
            NSString *title = alert.textFields[0].text;
            NSString *snippet = alert.textFields[1].text;
            NSString *lat = [NSString stringWithFormat:@"%.6f",self.myLocation.coordinate.latitude];
            NSString *lon = [NSString stringWithFormat:@"%.6f",self.myLocation.coordinate.longitude];
            
            /** 【mBaaS：データストア】位置情報の保存 **/
            // NCMBGeoPointの生成
            NCMBGeoPoint *geoPoint = [NCMBGeoPoint geoPointWithLatitude:lat.doubleValue longitude:lon.doubleValue];
            // NCMBObjectを生成
            NCMBObject *object = [NCMBObject objectWithClassName:@"GeoPoint"];
            // 値を設定
            [object setObject:geoPoint forKey:@"geolocation"];
            [object setObject:title forKey:@"title"];
            [object setObject:snippet forKey:@"snippet"];
            // 保存の実施
            [object saveInBackgroundWithBlock:^(NSError *error) {
                if (error) {
                    // 位置情報保存失敗時の処理
                    NSLog(@"位置情報の保存に失敗しました：%ld",(long)error.code);
                    self.label.text = [NSString stringWithFormat:@"位置情報の保存に失敗しました：%ld",(long)error.code];
                } else {
                    // 位置情報保存成功時の処理
                    NSLog(@"位置情報の保存に成功しました：%f,%f",geoPoint.latitude,geoPoint.longitude);
                    self.label.text = [NSString stringWithFormat:@"位置情報の保存に成功しました：%f,%f",geoPoint.latitude,geoPoint.longitude];
                    // マーカーを設置
                    [self addMarker:geoPoint.latitude longitude:geoPoint.longitude title:[object objectForKey:@"title"] snippet:[object objectForKey:@"snippet"] color:[UIColor blueColor]];
                }
            }];
        }]];
        // アラートのキャンセル押下時の処理
        [alert addAction:[UIAlertAction actionWithTitle:@"キャンセル" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
            NSLog(@"保存がキャンセルされました");
            self.label.text = @"保存がキャンセルされました";
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

// 「保存した場所を見る」ボタン押下時の処理
- (IBAction)getLocationData:(UIBarButtonItem *)sender {
    // Action Sheet
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"保存した場所を地図に表示します"
                                                                   message:@"検索範囲を選択してください"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    // iPadの場合
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        NSLog(@"iPad使用");
        actionSheet.popoverPresentationController.sourceView = self.view;
        actionSheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width*0.5, self.view.bounds.size.height*0.9, 1.0, 1.0);
        actionSheet.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionDown;
    }
    
    // キャンセル
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"キャンセル" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
    }]];
    
    // 検索条件を設定
    for (int i = 0; i < [SEAECH_RANGE count]; i++) {
        [actionSheet addAction:[UIAlertAction actionWithTitle:SEAECH_RANGE[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [self getLocaion:action.title];
        }]];
    }
    // アラートを表示する
    [self presentViewController:actionSheet animated:YES completion:nil];
}

/** 【mBaaS：データストア(位置情報)】保存データの取得 **/
- (void)getLocaion:(NSString *)title {
    // チェック
    if (!self.myLocation) {
        return;
    }
    
    // 現在地
    NCMBGeoPoint *geoPoint = [NCMBGeoPoint geoPointWithLatitude:self.myLocation.coordinate.latitude longitude:self.myLocation.coordinate.longitude];
    // 新宿駅
    NCMBGeoPoint *shinjukuGeoPoint = [NCMBGeoPoint geoPointWithLatitude:SHINJUKU_LAT longitude:SHINJUKU_LON];
    // 西新宿駅
    NCMBGeoPoint *westShinjukuGeoPoint = [NCMBGeoPoint geoPointWithLatitude:WEST_SHINJUKU_LAT longitude:WEST_SHINJUKU_LON];
    // それぞれのクラスの検索クエリを作成
    NCMBQuery *queryGeoPoint = [NCMBQuery queryWithClassName:@"GeoPoint"];
    NCMBQuery *queryShop = [NCMBQuery queryWithClassName:@"Shop"];
    // 検索条件を設定
    NSInteger index = [SEAECH_RANGE indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isEqualToString:title]) {
            return YES;
        }
        return NO;
    }];
    switch (index) {
        case 0:
            NSLog(@"%@",SEAECH_RANGE[0]);
            break;
        case 1:
            NSLog(@"%@",SEAECH_RANGE[1]);
            // 半径5km以内(円形検索)
            [queryGeoPoint whereKey:@"geolocation" nearGeoPoint:geoPoint withinKilometers:5.0f];
            [queryShop whereKey:@"geolocation" nearGeoPoint:geoPoint withinKilometers:5.0f];
            break;
        case 2:
            NSLog(@"%@",SEAECH_RANGE[2]);
            // 半径1km以内(円形検索)
            [queryGeoPoint whereKey:@"geolocation" nearGeoPoint:geoPoint withinKilometers:1.0f];
            [queryShop whereKey:@"geolocation" nearGeoPoint:geoPoint withinKilometers:1.0f];
            break;
        case 3:
            NSLog(@"%@",SEAECH_RANGE[3]);
            // 新宿駅と西新宿駅の間(矩形検索)
            [queryGeoPoint whereKey:@"geolocation" withinGeoBoxFromSouthwest:shinjukuGeoPoint toNortheast:westShinjukuGeoPoint];
            [queryShop whereKey:@"geolocation" withinGeoBoxFromSouthwest:shinjukuGeoPoint toNortheast:westShinjukuGeoPoint];
            break;
        default:
            NSLog(@"%@(エラー)",SEAECH_RANGE[0]);
            break;
    }
    // データストアを検索
    [queryGeoPoint findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (error) {
            // 検索失敗時の処理
            NSLog(@"GeoPointクラスの検索に失敗しました:%ld",(long)error.code);
            self.label.text = [NSString stringWithFormat:@"GeoPointクラスの検索に失敗しました:%ld",(long)error.code];
        } else {
            // 検索成功時の処理
            NSLog(@"GeoPointクラスの検索に成功しました");
            self.label.text = @"GeoPointクラスの検索に成功しました";
            for (NCMBObject *object in objects) {
                NCMBGeoPoint *point = [object objectForKey:@"geolocation"];
                [self addMarker:point.latitude longitude:point.longitude title:[object objectForKey:@"title"] snippet:[object objectForKey:@"snippet"] color:[UIColor blueColor]];
            }
        }
    }];
    [queryShop findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (error) {
            // 検索失敗時の処理
            NSLog(@"Shopクラスの検索に失敗しました:%ld",(long)error.code);
            self.label.text = [NSString stringWithFormat:@"Shopクラスの検索に失敗しました:%ld",(long)error.code];
        } else {
            // 検索成功時の処理
            NSLog(@"Shopクラスの検索に成功しました");
            self.label.text = @"Shopクラスの検索に成功しました";
            for (NCMBObject *object in objects) {
                NCMBGeoPoint *point = [object objectForKey:@"geolocation"];
                [self addImageMarker:point.latitude longitude:point.longitude title:[object objectForKey:@"shopName"] snippet:[object objectForKey:@"category"] imageName:[object objectForKey:@"image"]];
            }
        }
    }];
}

// 「お店（スプーンとフォーク）」ボタン押下時の処理
- (void)showShops:(UIBarButtonItem *)sender {
    // Shopデータの取得
    [self getShopData];
    // チェック
    if (!self.shopData) {
        NSLog(@"Shop情報の取得に失敗しました");
        self.label.text = @"Shop情報の取得に失敗しました";
        return;
    }
    
    NSLog(@"Shop情報の取得に成功しました");
    self.label.text = @"Shop情報の取得に成功しました";
    
    for (NCMBObject *object in self.shopData) {
        NCMBGeoPoint *point = [object objectForKey:@"geolocation"];
        [self addImageMarker:point.latitude longitude:point.longitude title:[object objectForKey:@"shopName"] snippet:[object objectForKey:@"category"] imageName:[object objectForKey:@"image"]];
    }
    
}

/** 【mBaaS：データストア】「Shop」クラスのデータを取得 **/
- (void)getShopData {
    // 「Shop」クラスの検索クエリを作成
    NCMBQuery *query = [NCMBQuery queryWithClassName:@"Shop"];
    // データストアを検索
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (error) {
            // 検索失敗時の処理
            NSLog(@"Shopクラス検索に失敗しました:%ld",(long)error.code);
        } else {
            // 検索成功時の処理
            NSLog(@"Shopクラス検索に成功しました");
            // AppDelegateに「Shop」クラスの情報を保持
            self.shopData = objects;
        }
    }];
}

// 「nifty」ボタン押下時の処理
- (IBAction)showNifty:(UIBarButtonItem *)sender {
    // マーカーを設定
    [self addImageMarker:NIFTY_LAT longitude:NIFTY_LON title:@"ニフティ株式会社" snippet:@"NIFTY Corporation" imageName:@"mBaaS.png"];
}

// 地図を表示
- (void)showMap:(CLLocationDegrees )latitude longitude:(CLLocationDegrees )longitude {
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:latitude longitude:longitude zoom:ZOOM];
    self.mapView.camera = camera;
    // 現在地の有効化
    self.mapView.myLocationEnabled = YES;
    // 現在地を示す青い点を表示
    self.mapView.settings.myLocationButton = YES;
}

// マーカー作成
- (void)addMarker:(CLLocationDegrees )latitude longitude:(CLLocationDegrees )longitude title:(NSString *)title snippet:(NSString *)snippet color:(UIColor *)color{
    
    self.marker = [[GMSMarker alloc]init];
    // 位置情報
    self.marker.position = CLLocationCoordinate2DMake(latitude, longitude);
    // タイトル
    self.marker.title = title;
    // コメント
    self.marker.snippet = snippet;
    // アイコン
    self.marker.icon = [GMSMarker markerImageWithColor:color];
    // マーカー表示時のアニメーションを設定
    self.marker.appearAnimation = kGMSMarkerAnimationPop;
    // マーカーを表示するマップの設定
    self.marker.map = self.mapView;
}

// マーカー作成（画像アイコン）
- (void)addImageMarker:(CLLocationDegrees )latitude longitude:(CLLocationDegrees )longitude title:(NSString *)title snippet:(NSString *)snippet imageName:(NSString *)imageName {
    GMSMarker *marker = [[GMSMarker alloc]init];
    // 位置情報
    marker.position = CLLocationCoordinate2DMake(latitude, longitude);
    // shopName
    marker.title = title;
    // category
    marker.snippet = snippet;
    
    /** 【mBaaS：ファイルストア】アイコン画像データを取得 **/
    // ファイル名を設定
    NCMBFile *imageFile = [NCMBFile fileWithName:imageName data:nil];
    // ファイルを検索
    [imageFile getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        if (error) {
            // ファイル取得失敗時の処理
            NSLog(@"%@icon画像の取得に失敗しました:%ld",snippet,(long)error.code);
        } else {
            // ファイル取得成功時の処理
            NSLog(@"%@icon画像の取得に成功しました",snippet);
            // 画像アイコン
            marker.icon = [UIImage imageWithData:data];
        }
    }];
    // マーカー表示時のアニメーションを設定
    marker.appearAnimation = kGMSMarkerAnimationPop;
    // マーカーを表示するマップの設定
    marker.map = self.mapView;
}

// 「ゴミ箱」ボタン押下時の処理
- (IBAction)clearMarker:(UIBarButtonItem *)sender {
    // マーカーを全てクリアする
    [self.mapView clear];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
