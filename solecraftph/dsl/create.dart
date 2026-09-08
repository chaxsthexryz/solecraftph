library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildSoleCraftApp,
      apiKey: options.apiKey,
      baseUrl: options.baseUrl,
      projectName: options.projectName,
      projectId: options.projectId,
      findOrCreate: options.findOrCreate,
      allowNewProject: options.allowNewProject,
      dryRun: options.dryRun,
      commitMessage: options.commitMessage,
    );
  } catch (error) {
    stderr.writeln('Error: ${formatFlutterFlowAIError(error)}');
    exit(1);
  }
}

const String kBaseUrl = 'https://snow-jellyfish-553645.hostingersite.com/api';

void buildSoleCraftApp(App app) {
  // ========================= THEME =========================
  app.themeColor('primary', 0xFFE1541B); // brand orange
  app.themeColor('secondary', 0xFF20201C); // ink
  app.themeColor('tertiary', 0xFFB9791A); // amber (Best Seller)
  app.themeColor('alternate', 0xFFE2DED4); // hairline
  app.themeColor('primaryBackground', 0xFFF7F5F0); // warm paper
  app.themeColor('secondaryBackground', 0xFFFFFFFF);
  app.themeColor('primaryText', 0xFF20201C);
  app.themeColor('secondaryText', 0xFF6B6862);
  app.primaryFont('Inter');

  app.constant('storeName', 'SoleCraftPH');

  // ====================== DATA MODEL =======================
  final product = app.struct('Product', {
    'id': int_,
    'name': string,
    'category': string,
    'subcategory': string,
    'description': string,
    'price': double_,
    'sale_price': double_,
    'stock': int_,
    'badge': string,
    'image': string,
    'on_sale': bool_,
  });

  final review = app.struct('Review', {
    'id': int_,
    'rating': int_,
    'comment': string,
    'reviewer': string,
    'created_at': string,
  });

  final banner = app.struct('Banner', {
    'id': int_,
    'title': string,
    'subtitle': string,
    'link_url': string,
  });

  final cartItem = app.struct('CartItem', {
    'productId': int_,
    'name': string,
    'price': double_,
    'image': string,
    'quantity': int_,
  });

  final orderSummary = app.struct('OrderSummary', {
    'id': int_,
    'total_amount': double_,
    'status': string,
    'payment_method': string,
    'created_at': string,
    'item_count': int_,
  });

  final orderItem = app.struct('OrderItem', {
    'product_name': string,
    'unit_price': double_,
    'quantity': int_,
    'subtotal': double_,
  });

  final statusLog = app.struct('StatusLog', {
    'status': string,
    'note': string,
    'created_at': string,
  });

  final orderHead = app.struct('OrderHead', {
    'id': int_,
    'status': string,
    'total_amount': double_,
    'payment_method': string,
    'created_at': string,
  });

  // ---- Envelope response shapes ({success, message, data}) ----
  final apiUser = app.struct('ApiUser', {
    'id': int_,
    'username': string,
    'full_name': string,
    'email': string,
    'phone': string,
    'address': string,
    'role': string,
  });
  final authData = app.struct('AuthData', {
    'token': string,
    'expires_at': string,
    'user': apiUser,
  });
  final authResponse = app.struct('AuthResponse', {
    'success': bool_,
    'message': string,
    'data': authData,
  });
  final productsData = app.struct('ProductsData', {
    'products': listOf(product),
  });
  final productsResponse = app.struct('ProductsResponse', {
    'success': bool_,
    'message': string,
    'data': productsData,
  });
  final detailResponse = app.struct('DetailResponse', {
    'success': bool_,
    'message': string,
    'data': product,
  });
  final reviewsData = app.struct('ReviewsData', {'reviews': listOf(review)});
  final reviewsResponse = app.struct('ReviewsResponse', {
    'success': bool_,
    'message': string,
    'data': reviewsData,
  });
  final bannersData = app.struct('BannersData', {'banners': listOf(banner)});
  final bannersResponse = app.struct('BannersResponse', {
    'success': bool_,
    'message': string,
    'data': bannersData,
  });
  final checkoutData = app.struct('CheckoutData', {
    'order_id': int_,
    'total_amount': double_,
    'status': string,
  });
  final checkoutResponse = app.struct('CheckoutResponse', {
    'success': bool_,
    'message': string,
    'data': checkoutData,
  });
  final ordersData = app.struct('OrdersData', {
    'orders': listOf(orderSummary),
  });
  final ordersResponse = app.struct('OrdersResponse', {
    'success': bool_,
    'message': string,
    'data': ordersData,
  });
  final orderDetailData = app.struct('OrderDetailData', {
    'order': orderHead,
    'items': listOf(orderItem),
    'timeline': listOf(statusLog),
  });
  final orderDetailResponse = app.struct('OrderDetailResponse', {
    'success': bool_,
    'message': string,
    'data': orderDetailData,
  });
  final wishlistData = app.struct('WishlistData', {
    'wishlist': listOf(product),
  });
  final wishlistResponse = app.struct('WishlistResponse', {
    'success': bool_,
    'message': string,
    'data': wishlistData,
  });

  // Serialize the local cart into a JSON array string for checkout.
  final cartToJson = app.customFunction(
    'cartToJson',
    args: {'items': listOf(cartItem)},
    returns: string,
    description: 'Serialize cart items to a JSON array for the checkout API.',
    code: r'''
final list = (items)
    .map((e) => {'product_id': e.productId, 'quantity': e.quantity})
    .toList();
return jsonEncode(list);
''',
  );

  // ====================== APP STATE ========================
  app.state('authToken', string, persisted: true);
  app.state('isLoggedIn', bool_, persisted: true);
  app.state('userId', int_, persisted: true);
  app.state('userName', string, persisted: true);
  app.state('userEmail', string, persisted: true);
  app.state('userPhone', string, persisted: true);
  app.state('userAddress', string, persisted: true);
  app.state('cartItems', listOf(cartItem), persisted: true);

  // ========================= API ===========================
  final loginUser = Endpoint.post(
    'LoginUser',
    '/auth/login.php',
    variables: {'login': string, 'password': string},
    body: const {'login': '<login>', 'password': '<password>'},
    response: authResponse,
  );
  final registerUser = Endpoint.post(
    'RegisterUser',
    '/auth/register.php',
    variables: {
      'username': string,
      'email': string,
      'password': string,
      'full_name': string,
      'phone': string,
      'address': string,
    },
    body: const {
      'username': '<username>',
      'email': '<email>',
      'password': '<password>',
      'full_name': '<full_name>',
      'phone': '<phone>',
      'address': '<address>',
    },
    response: authResponse,
  );
  final logoutUser = Endpoint.post(
    'LogoutUser',
    '/auth/logout.php',
    variables: {'token': string},
    headers: const {'Authorization': 'Bearer <token>'},
  );
  final getProducts = Endpoint.get(
    'GetProducts',
    '/products.php?category=[category]&search=[search]',
    variables: {'category': string, 'search': string},
    response: productsResponse,
  );
  final getProductDetail = Endpoint.get(
    'GetProductDetail',
    '/products/detail.php?id=[id]',
    variables: {'id': int_},
    response: detailResponse,
  );
  final getReviews = Endpoint.get(
    'GetReviews',
    '/products/reviews.php?product_id=[productId]',
    variables: {'productId': int_},
    response: reviewsResponse,
  );
  final submitReview = Endpoint.post(
    'SubmitReview',
    '/products/review.php',
    variables: {
      'productId': int_,
      'rating': int_,
      'comment': string,
      'token': string,
    },
    headers: const {'Authorization': 'Bearer <token>'},
    body: const {
      'product_id': '<productId>',
      'rating': '<rating>',
      'comment': '<comment>',
    },
  );
  final getBanners = Endpoint.get(
    'GetBanners',
    '/banners.php',
    response: bannersResponse,
  );
  final getCategories = Endpoint.get('GetCategories', '/categories.php');
  final checkout = Endpoint.post(
    'Checkout',
    '/checkout.php',
    variables: {
      'customerName': string,
      'customerEmail': string,
      'customerPhone': string,
      'customerAddress': string,
      'paymentMethod': string,
      'cartJson': string,
      'token': string,
    },
    headers: const {'Authorization': 'Bearer <token>'},
    body: const {
      'customer_name': '<customerName>',
      'customer_email': '<customerEmail>',
      'customer_phone': '<customerPhone>',
      'customer_address': '<customerAddress>',
      'payment_method': '<paymentMethod>',
      'cart': '<cartJson>',
    },
    response: checkoutResponse,
  );
  final getOrders = Endpoint.get(
    'GetOrders',
    '/orders.php',
    variables: {'token': string},
    headers: const {'Authorization': 'Bearer <token>'},
    response: ordersResponse,
  );
  final getOrderDetail = Endpoint.get(
    'GetOrderDetail',
    '/orders/detail.php?id=[id]',
    variables: {'id': int_, 'token': string},
    headers: const {'Authorization': 'Bearer <token>'},
    response: orderDetailResponse,
  );
  final getWishlist = Endpoint.get(
    'GetWishlist',
    '/wishlist.php',
    variables: {'token': string},
    headers: const {'Authorization': 'Bearer <token>'},
    response: wishlistResponse,
  );
  final toggleWishlist = Endpoint.post(
    'ToggleWishlist',
    '/wishlist/toggle.php',
    variables: {'productId': int_, 'token': string},
    headers: const {'Authorization': 'Bearer <token>'},
    body: const {'product_id': '<productId>'},
  );
  final getProfile = Endpoint.get(
    'GetProfile',
    '/profile.php',
    variables: {'token': string},
    headers: const {'Authorization': 'Bearer <token>'},
  );
  final updateProfile = Endpoint.post(
    'UpdateProfile',
    '/profile/update.php',
    variables: {
      'fullName': string,
      'phone': string,
      'address': string,
      'token': string,
    },
    headers: const {'Authorization': 'Bearer <token>'},
    body: const {
      'full_name': '<fullName>',
      'phone': '<phone>',
      'address': '<address>',
    },
  );
  final sendContact = Endpoint.post(
    'SendContact',
    '/contact.php',
    variables: {
      'name': string,
      'email': string,
      'subject': string,
      'message': string,
    },
    body: const {
      'name': '<name>',
      'email': '<email>',
      'subject': '<subject>',
      'message': '<message>',
    },
  );

  app.apiGroup(
    'SoleCraftAPI',
    baseUrl: kBaseUrl,
    headers: const {'Content-Type': 'application/json'},
    endpoints: [
      loginUser,
      registerUser,
      logoutUser,
      getProducts,
      getProductDetail,
      getReviews,
      submitReview,
      getBanners,
      getCategories,
      checkout,
      getOrders,
      getOrderDetail,
      getWishlist,
      toggleWishlist,
      getProfile,
      updateProfile,
      sendContact,
    ],
  );

  // ===================== COMPONENTS ========================
  final dynamic productCard = app.component(
    'ProductCard',
    description: 'Product tile: image, badge, name, price/sale price.',
    params: {
      'productName': string,
      'price': double_,
      'image': string,
      'badge': string,
      'onTapAction': action,
    },
    body: Container(
      onTap: ParamAction('onTapAction'),
      color: Colors.secondaryBackground,
      borderRadius: 12,
      child: Column(
        crossAxis: CrossAxis.start,
        children: [
          Stack(
            children: [
              Image(
                Param('image'),
                width: double.infinity,
                height: 130,
                fit: ImageFit.cover,
                borderRadius: 12,
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: EdgeInsets.only(left: 8, top: 8),
                color: Colors.primary,
                borderRadius: 6,
                visible: Not(Equals(Param('badge'), '')),
                child: Text(
                  Param('badge'),
                  style: Styles.labelSmall,
                  color: Colors.primaryBackground,
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxis: CrossAxis.start,
              spacing: 4,
              children: [
                Text(
                  Param('productName'),
                  style: Styles.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  spacing: 6,
                  crossAxis: CrossAxis.center,
                  children: [
                    Text(
                      '₱',
                      style: Styles.titleSmall,
                      color: Colors.primary,
                    ),
                    Text(
                      Param('price'),
                      style: Styles.titleSmall,
                      color: Colors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // ======================== PAGES ==========================

  // ---- 1. Splash ----
  app.page(
    'SplashPage',
    route: '/',
    isInitial: true,
    description: 'Brand splash and entry point.',
    body: Scaffold(
      body: Container(
        color: Colors.primaryBackground,
        width: double.infinity,
        padding: 32,
        child: Column(
          mainAxis: MainAxis.center,
          crossAxis: CrossAxis.center,
          spacing: 16,
          children: [
            Icon('shopping_bag', size: 72, color: Colors.primary),
            Text('SoleCraftPH', style: Styles.headlineMedium),
            Text(
              'Footwear, Done Right',
              style: Styles.bodyLarge,
              color: Colors.secondaryText,
            ),
            Button(
              'Get Started',
              width: double.infinity,
              height: 48,
              color: Colors.primary,
              textColor: Colors.primaryBackground,
              onTap: Navigate('LoginPage'),
            ),
            Button(
              'Browse as Guest',
              variant: ButtonVariant.outlined,
              width: double.infinity,
              height: 48,
              onTap: Navigate('ShopHomePage'),
            ),
          ],
        ),
      ),
    ),
  );

  // ---- 2. Login ----
  app.page(
    'LoginPage',
    route: '/login',
    description: 'Sign in with email/username and password.',
    state: {'login': string, 'password': string, 'busy': bool_},
    body: Scaffold(
      appBar: AppBar(title: 'Sign In'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 24,
        child: Column(
          scrollable: true,
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            Text('Welcome back', style: Styles.headlineMedium),
            TextField(
              name: 'loginField',
              label: 'Email or Username',
              onChanged: SetState('login', TextValue()),
            ),
            TextField(
              name: 'passwordField',
              label: 'Password',
              obscureText: true,
              onChanged: SetState('password', TextValue()),
            ),
            Button(
              'Sign In',
              width: double.infinity,
              height: 48,
              color: Colors.primary,
              textColor: Colors.primaryBackground,
              onTap: [
                ApiCall(
                  loginUser,
                  params: {
                    'login': State('login'),
                    'password': State('password'),
                  },
                  onSuccess: (res) => [
                    UpdateAppState.set('authToken', res['data']['token']),
                    UpdateAppState.set('isLoggedIn', true),
                    UpdateAppState.set('userId', res['data']['user']['id']),
                    UpdateAppState.set(
                      'userName',
                      res['data']['user']['full_name'],
                    ),
                    UpdateAppState.set(
                      'userEmail',
                      res['data']['user']['email'],
                    ),
                    UpdateAppState.set(
                      'userPhone',
                      res['data']['user']['phone'],
                    ),
                    UpdateAppState.set(
                      'userAddress',
                      res['data']['user']['address'],
                    ),
                    Navigate('ShopHomePage'),
                  ],
                  onFailure: [Snackbar('Invalid credentials. Please try again.')],
                ),
              ],
            ),
            Button(
              'Create an account',
              variant: ButtonVariant.text,
              width: double.infinity,
              onTap: Navigate('RegisterPage'),
            ),
          ],
        ),
      ),
    ),
  );

  // ---- 3. Register ----
  app.page(
    'RegisterPage',
    route: '/register',
    description: 'Create a new customer account.',
    state: {
      'username': string,
      'fullName': string,
      'email': string,
      'phone': string,
      'address': string,
      'password': string,
    },
    body: Scaffold(
      appBar: AppBar(title: 'Create Account'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 24,
        child: Column(
          scrollable: true,
          crossAxis: CrossAxis.start,
          spacing: 14,
          children: [
            TextField(
              label: 'Username',
              onChanged: SetState('username', TextValue()),
            ),
            TextField(
              label: 'Full Name',
              onChanged: SetState('fullName', TextValue()),
            ),
            TextField(
              label: 'Email',
              keyboard: Keyboard.email,
              onChanged: SetState('email', TextValue()),
            ),
            TextField(
              label: 'Phone',
              keyboard: Keyboard.number,
              onChanged: SetState('phone', TextValue()),
            ),
            TextField(
              label: 'Address',
              onChanged: SetState('address', TextValue()),
            ),
            TextField(
              label: 'Password',
              obscureText: true,
              onChanged: SetState('password', TextValue()),
            ),
            Button(
              'Register',
              width: double.infinity,
              height: 48,
              color: Colors.primary,
              textColor: Colors.primaryBackground,
              onTap: [
                ApiCall(
                  registerUser,
                  params: {
                    'username': State('username'),
                    'email': State('email'),
                    'password': State('password'),
                    'full_name': State('fullName'),
                    'phone': State('phone'),
                    'address': State('address'),
                  },
                  onSuccess: (res) => [
                    UpdateAppState.set('authToken', res['data']['token']),
                    UpdateAppState.set('isLoggedIn', true),
                    UpdateAppState.set('userId', res['data']['user']['id']),
                    UpdateAppState.set('userName', State('fullName')),
                    UpdateAppState.set('userEmail', State('email')),
                    UpdateAppState.set('userPhone', State('phone')),
                    UpdateAppState.set('userAddress', State('address')),
                    Navigate('ShopHomePage'),
                  ],
                  onFailure: [Snackbar('Registration failed. Try a different email/username.')],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  // ---- 4. Home ----
  app.page(
    'ShopHomePage',
    route: '/home',
    description: 'Banners, category tabs and the product grid.',
    state: {
      'products': listOf(product),
      'banners': listOf(banner),
      'searchQuery': string,
      'loading': bool_.withDefault(true),
    },
    onLoad: [
      ApiCall(
        getBanners,
        outputAs: 'bannersOut',
        onSuccess: (res) => [SetState('banners', res['data']['banners'])],
      ),
      ApiCall(
        getProducts,
        outputAs: 'productsOut',
        onSuccess: (res) => [
          SetState('products', res['data']['products']),
          SetState('loading', false),
        ],
        onFailure: [
          SetState('loading', false),
          Snackbar('Could not load products.'),
        ],
      ),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'SoleCraftPH'),
      body: Container(
        color: Colors.primaryBackground,
        child: Column(
          scrollable: true,
          crossAxis: CrossAxis.start,
          children: [
            // Search
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                name: 'searchField',
                hint: 'Search shoes...',
                prefixIcon: 'search',
                onChanged: SetState('searchQuery', TextValue()),
                onSubmitted: [
                  ApiCall(
                    getProducts,
                    params: {'search': State('searchQuery'), 'category': ''},
                    onSuccess: (res) => [
                      SetState('products', res['data']['products']),
                    ],
                    onFailure: [Snackbar('Search failed.')],
                  ),
                ],
              ),
            ),
            // Banners
            Container(
              height: 130,
              padding: EdgeInsets.only(left: 16),
              child: ListView(
                source: State('banners'),
                horizontal: true,
                shrinkWrap: true,
                itemBuilder: (item) => Container(
                  width: 280,
                  margin: EdgeInsets.only(right: 12),
                  padding: 16,
                  borderRadius: 16,
                  color: Colors.secondary,
                  child: Column(
                    mainAxis: MainAxis.center,
                    crossAxis: CrossAxis.start,
                    spacing: 6,
                    children: [
                      Text(
                        item['title'],
                        style: Styles.titleMedium,
                        color: Colors.primaryBackground,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item['subtitle'],
                        style: Styles.bodySmall,
                        color: Colors.alternate,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Category chips
            Row(
              scrollable: true,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              spacing: 8,
              children: [
                Button(
                  'All',
                  variant: ButtonVariant.outlined,
                  borderRadius: 20,
                  onTap: [
                    ApiCall(
                      getProducts,
                      params: {'category': '', 'search': ''},
                      onSuccess: (res) => [
                        SetState('products', res['data']['products']),
                      ],
                    ),
                  ],
                ),
                Button(
                  'Athletic',
                  variant: ButtonVariant.outlined,
                  borderRadius: 20,
                  onTap: [
                    ApiCall(
                      getProducts,
                      params: {
                        'category': 'Athletic & Performance',
                        'search': '',
                      },
                      onSuccess: (res) => [
                        SetState('products', res['data']['products']),
                      ],
                    ),
                  ],
                ),
                Button(
                  'Casual',
                  variant: ButtonVariant.outlined,
                  borderRadius: 20,
                  onTap: [
                    ApiCall(
                      getProducts,
                      params: {
                        'category': 'Casual & Lifestyle',
                        'search': '',
                      },
                      onSuccess: (res) => [
                        SetState('products', res['data']['products']),
                      ],
                    ),
                  ],
                ),
                Button(
                  'Formal',
                  variant: ButtonVariant.outlined,
                  borderRadius: 20,
                  onTap: [
                    ApiCall(
                      getProducts,
                      params: {
                        'category': 'Formal & Dress',
                        'search': '',
                      },
                      onSuccess: (res) => [
                        SetState('products', res['data']['products']),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            ProgressBar.circular(
              size: 32,
              thickness: 3,
              visible: State('loading'),
            ),
            // Product grid
            GridView(
              source: State('products'),
              columns: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.62,
              padding: EdgeInsets.all(16),
              itemBuilder: (item) => productCard(
                productName: item['name'],
                price: item['price'],
                image: item['image'],
                badge: item['badge'],
                onTapAction: Navigate(
                  'ProductDetailPage',
                  params: {'productId': item['id']},
                ),
              ),
            ),
            // Quick nav
            Row(
              mainAxis: MainAxis.spaceAround,
              padding: 12,
              children: [
                IconButton(
                  'shopping_cart',
                  size: 26,
                  color: Colors.primary,
                  onTap: Navigate('CartPage'),
                ),
                IconButton(
                  'favorite',
                  size: 26,
                  color: Colors.primary,
                  onTap: Navigate('WishlistPage'),
                ),
                IconButton(
                  'receipt_long',
                  size: 26,
                  color: Colors.primary,
                  onTap: Navigate('OrdersPage'),
                ),
                IconButton(
                  'person',
                  size: 26,
                  color: Colors.primary,
                  onTap: Navigate('ProfilePage'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  // ---- 5. Product detail ----
  app.page(
    'ProductDetailPage',
    route: '/product',
    description: 'Product info, reviews, add to cart / wishlist.',
    params: {'productId': int_.withDefault(0)},
    state: {
      'product': product,
      'reviews': listOf(review),
      'loading': bool_.withDefault(true),
      'reviewRating': int_.withDefault(5),
      'reviewComment': string,
    },
    onLoad: [
      ApiCall(
        getProductDetail,
        outputAs: 'detailOut',
        params: {'id': PageParam('productId')},
        onSuccess: (res) => [
          SetState('product', res['data']),
          SetState('loading', false),
        ],
        onFailure: [
          SetState('loading', false),
          Snackbar('Product not found.'),
        ],
      ),
      ApiCall(
        getReviews,
        outputAs: 'reviewsOut',
        params: {'productId': PageParam('productId')},
        onSuccess: (res) => [SetState('reviews', res['data']['reviews'])],
      ),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Details'),
      body: Container(
        color: Colors.primaryBackground,
        child: Column(
          scrollable: true,
          crossAxis: CrossAxis.start,
          spacing: 12,
          children: [
            Image(
              State('product')['image'],
              width: double.infinity,
              height: 280,
              fit: ImageFit.cover,
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxis: CrossAxis.start,
                spacing: 10,
                children: [
                  Text(State('product')['name'], style: Styles.headlineSmall),
                  Row(
                    spacing: 6,
                    children: [
                      Text('₱', style: Styles.titleLarge, color: Colors.primary),
                      Text(
                        State('product')['price'],
                        style: Styles.titleLarge,
                        color: Colors.primary,
                      ),
                    ],
                  ),
                  Text(
                    State('product')['description'],
                    style: Styles.bodyMedium,
                    color: Colors.secondaryText,
                  ),
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        Button(
                          'Add to Cart',
                          icon: 'shopping_cart',
                          height: 48,
                          color: Colors.primary,
                          textColor: Colors.primaryBackground,
                          onTap: [
                            UpdateAppState.addToList(
                              'cartItems',
                              Struct(cartItem, {
                                'productId': State('product')['id'],
                                'name': State('product')['name'],
                                'price': State('product')['price'],
                                'image': State('product')['image'],
                                'quantity': 1,
                              }),
                            ),
                            Snackbar('Added to cart'),
                          ],
                        ),
                      ),
                      IconButton(
                        'favorite_border',
                        size: 26,
                        color: Colors.primary,
                        fillColor: Colors.secondaryBackground,
                        borderRadius: 8,
                        onTap: [
                          ApiCall(
                            toggleWishlist,
                            params: {
                              'productId': PageParam('productId'),
                              'token': AppState('authToken'),
                            },
                            onSuccess: (res) => [Snackbar('Wishlist updated')],
                            onFailure: [Snackbar('Please sign in to use wishlist.')],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Divider(),
                  Text('Reviews', style: Styles.titleMedium),
                  ListView(
                    source: State('reviews'),
                    shrinkWrap: true,
                    spacing: 8,
                    itemBuilder: (item) => Container(
                      padding: 12,
                      borderRadius: 8,
                      color: Colors.secondaryBackground,
                      child: Column(
                        crossAxis: CrossAxis.start,
                        spacing: 4,
                        children: [
                          Row(
                            spacing: 6,
                            children: [
                              Icon('star', size: 16, color: Colors.tertiary),
                              Text(item['rating'], style: Styles.labelMedium),
                              Text(
                                item['reviewer'],
                                style: Styles.labelSmall,
                                color: Colors.secondaryText,
                              ),
                            ],
                          ),
                          Text(item['comment'], style: Styles.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  Divider(),
                  Text('Write a review', style: Styles.titleMedium),
                  TextField(
                    label: 'Rating (1-5)',
                    keyboard: Keyboard.number,
                    onChanged: SetState('reviewRating', TextValue().asInt()),
                  ),
                  TextField(
                    label: 'Comment',
                    onChanged: SetState('reviewComment', TextValue()),
                  ),
                  Button(
                    'Submit Review',
                    width: double.infinity,
                    height: 44,
                    variant: ButtonVariant.outlined,
                    onTap: [
                      ApiCall(
                        submitReview,
                        params: {
                          'productId': PageParam('productId'),
                          'rating': State('reviewRating'),
                          'comment': State('reviewComment'),
                          'token': AppState('authToken'),
                        },
                        onSuccess: (res) => [
                          Snackbar('Review submitted'),
                          ApiCall(
                            getReviews,
                            params: {'productId': PageParam('productId')},
                            onSuccess: (r) => [
                              SetState('reviews', r['data']['reviews']),
                            ],
                          ),
                        ],
                        onFailure: [Snackbar('Please sign in to review.')],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ---- 6. Cart ----
  app.page(
    'CartPage',
    route: '/cart',
    description: 'Local cart with quantity controls.',
    body: Scaffold(
      appBar: AppBar(title: 'Cart'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 16,
        child: Column(
          spacing: 12,
          children: [
            Expanded(
              ListView(
                source: AppState('cartItems'),
                spacing: 8,
                itemBuilder: (item) => Container(
                  padding: 10,
                  borderRadius: 10,
                  color: Colors.secondaryBackground,
                  child: Row(
                    crossAxis: CrossAxis.center,
                    spacing: 10,
                    children: [
                      Image(
                        item['image'],
                        width: 56,
                        height: 56,
                        fit: ImageFit.cover,
                        borderRadius: 8,
                      ),
                      Expanded(
                        Column(
                          crossAxis: CrossAxis.start,
                          spacing: 2,
                          children: [
                            Text(
                              item['name'],
                              style: Styles.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              spacing: 3,
                              children: [
                                Text('₱', style: Styles.labelMedium),
                                Text(item['price'], style: Styles.labelMedium),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        spacing: 3,
                        children: [
                          Text(
                            'Qty',
                            style: Styles.bodySmall,
                            color: Colors.secondaryText,
                          ),
                          Text(item['quantity'], style: Styles.titleSmall),
                        ],
                      ),
                      IconButton(
                        'delete_outline',
                        size: 20,
                        color: Colors.error,
                        onTap: [
                          UpdateAppState.removeAtIndex('cartItems', item.index),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Button(
              'Proceed to Checkout',
              width: double.infinity,
              height: 50,
              color: Colors.primary,
              textColor: Colors.primaryBackground,
              onTap: Navigate('CheckoutPage'),
            ),
          ],
        ),
      ),
    ),
  );

  // ---- 7. Checkout ----
  app.page(
    'CheckoutPage',
    route: '/checkout',
    description: 'Shipping details, payment method and order submission.',
    state: {
      'name': string,
      'email': string,
      'phone': string,
      'address': string,
      'paymentMethod': string.withDefault('COD'),
    },
    onLoad: [
      SetState('name', AppState('userName')),
      SetState('email', AppState('userEmail')),
      SetState('phone', AppState('userPhone')),
      SetState('address', AppState('userAddress')),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Checkout'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 20,
        child: Column(
          scrollable: true,
          crossAxis: CrossAxis.start,
          spacing: 14,
          children: [
            Text('Shipping details', style: Styles.titleMedium),
            TextField(
              label: 'Full Name',
              onChanged: SetState('name', TextValue()),
            ),
            TextField(
              label: 'Email',
              keyboard: Keyboard.email,
              onChanged: SetState('email', TextValue()),
            ),
            TextField(
              label: 'Phone',
              keyboard: Keyboard.number,
              onChanged: SetState('phone', TextValue()),
            ),
            TextField(
              label: 'Address',
              onChanged: SetState('address', TextValue()),
            ),
            Text('Payment method', style: Styles.titleMedium),
            Row(
              spacing: 8,
              children: [
                Button(
                  'COD',
                  variant: ButtonVariant.outlined,
                  borderRadius: 20,
                  onTap: SetState('paymentMethod', 'COD'),
                ),
                Button(
                  'GCASH',
                  variant: ButtonVariant.outlined,
                  borderRadius: 20,
                  onTap: SetState('paymentMethod', 'GCASH'),
                ),
                Button(
                  'CARD',
                  variant: ButtonVariant.outlined,
                  borderRadius: 20,
                  onTap: SetState('paymentMethod', 'CARD'),
                ),
              ],
            ),
            Row(
              spacing: 6,
              children: [
                Text('Selected:', style: Styles.bodySmall),
                Text(State('paymentMethod'), style: Styles.labelMedium),
              ],
            ),
            Button(
              'Place Order',
              width: double.infinity,
              height: 50,
              color: Colors.primary,
              textColor: Colors.primaryBackground,
              onTap: [
                ApiCall(
                  checkout,
                  params: {
                    'customerName': State('name'),
                    'customerEmail': State('email'),
                    'customerPhone': State('phone'),
                    'customerAddress': State('address'),
                    'paymentMethod': State('paymentMethod'),
                    'cartJson': CustomFunction(
                      cartToJson,
                      args: {'items': AppState('cartItems')},
                    ),
                    'token': AppState('authToken'),
                  },
                  onSuccess: (res) => [
                    ClearAppState('cartItems'),
                    Navigate(
                      'OrderConfirmationPage',
                      params: {'orderId': res['data']['order_id']},
                    ),
                  ],
                  onFailure: [Snackbar('Could not place order. Please try again.')],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  // ---- 8. Order confirmation ----
  app.page(
    'OrderConfirmationPage',
    route: '/order-confirmation',
    description: 'Confirmation after a successful checkout.',
    params: {'orderId': int_.withDefault(0)},
    body: Scaffold(
      body: Container(
        color: Colors.primaryBackground,
        width: double.infinity,
        padding: 32,
        child: Column(
          mainAxis: MainAxis.center,
          crossAxis: CrossAxis.center,
          spacing: 16,
          children: [
            Icon('check_circle', size: 84, color: Colors.success),
            Text('Order placed!', style: Styles.headlineMedium),
            Row(
              spacing: 6,
              mainAxis: MainAxis.center,
              children: [
                Text('Order #', style: Styles.bodyLarge),
                Text(PageParam('orderId'), style: Styles.titleMedium),
              ],
            ),
            Button(
              'View My Orders',
              width: double.infinity,
              height: 48,
              color: Colors.primary,
              textColor: Colors.primaryBackground,
              onTap: Navigate('OrdersPage'),
            ),
            Button(
              'Continue Shopping',
              variant: ButtonVariant.outlined,
              width: double.infinity,
              height: 48,
              onTap: Navigate('ShopHomePage'),
            ),
          ],
        ),
      ),
    ),
  );

  // ---- 9. Orders history ----
  app.page(
    'OrdersPage',
    route: '/orders',
    description: 'Authenticated order history.',
    state: {'orders': listOf(orderSummary), 'loading': bool_.withDefault(true)},
    onLoad: [
      ApiCall(
        getOrders,
        params: {'token': AppState('authToken')},
        onSuccess: (res) => [
          SetState('orders', res['data']['orders']),
          SetState('loading', false),
        ],
        onFailure: [
          SetState('loading', false),
          Snackbar('Please sign in to view orders.'),
        ],
      ),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'My Orders'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 16,
        child: Column(
          spacing: 10,
          children: [
            ProgressBar.circular(
              size: 30,
              thickness: 3,
              visible: State('loading'),
            ),
            Expanded(
              ListView(
                source: State('orders'),
                spacing: 8,
                itemBuilder: (item) => Container(
                  padding: 14,
                  borderRadius: 10,
                  color: Colors.secondaryBackground,
                  onTap: Navigate(
                    'OrderDetailPage',
                    params: {'orderId': item['id']},
                  ),
                  child: Row(
                    mainAxis: MainAxis.spaceBetween,
                    children: [
                      Column(
                        crossAxis: CrossAxis.start,
                        spacing: 4,
                        children: [
                          Row(
                            spacing: 4,
                            children: [
                              Text('Order #', style: Styles.labelMedium),
                              Text(item['id'], style: Styles.labelMedium),
                            ],
                          ),
                          Text(
                            item['status'],
                            style: Styles.bodySmall,
                            color: Colors.secondaryText,
                          ),
                        ],
                      ),
                      Row(
                        spacing: 3,
                        children: [
                          Text('₱', style: Styles.titleSmall, color: Colors.primary),
                          Text(
                            item['total_amount'],
                            style: Styles.titleSmall,
                            color: Colors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ---- 10. Order detail ----
  app.page(
    'OrderDetailPage',
    route: '/order-detail',
    description: 'Order items and status timeline.',
    params: {'orderId': int_.withDefault(0)},
    state: {
      'items': listOf(orderItem),
      'timeline': listOf(statusLog),
      'status': string,
      'total': double_,
    },
    onLoad: [
      ApiCall(
        getOrderDetail,
        params: {'id': PageParam('orderId'), 'token': AppState('authToken')},
        onSuccess: (res) => [
          SetState('items', res['data']['items']),
          SetState('timeline', res['data']['timeline']),
          SetState('status', res['data']['order']['status']),
          SetState('total', res['data']['order']['total_amount']),
        ],
        onFailure: [Snackbar('Could not load order.')],
      ),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Order Detail'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 16,
        child: Column(
          scrollable: true,
          crossAxis: CrossAxis.start,
          spacing: 12,
          children: [
            Row(
              spacing: 8,
              children: [
                Text('Status:', style: Styles.titleMedium),
                Text(State('status'), style: Styles.titleMedium, color: Colors.primary),
              ],
            ),
            Text('Items', style: Styles.titleMedium),
            ListView(
              source: State('items'),
              shrinkWrap: true,
              spacing: 6,
              itemBuilder: (item) => Container(
                padding: 12,
                borderRadius: 8,
                color: Colors.secondaryBackground,
                child: Row(
                  mainAxis: MainAxis.spaceBetween,
                  children: [
                    Expanded(
                      Text(
                        item['product_name'],
                        style: Styles.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(item['quantity'], style: Styles.bodySmall),
                    Row(
                      spacing: 2,
                      children: [
                        Text('₱', style: Styles.labelMedium),
                        Text(item['subtotal'], style: Styles.labelMedium),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Divider(),
            Text('Timeline', style: Styles.titleMedium),
            ListView(
              source: State('timeline'),
              shrinkWrap: true,
              spacing: 6,
              itemBuilder: (item) => Row(
                spacing: 8,
                crossAxis: CrossAxis.start,
                children: [
                  Icon('radio_button_checked', size: 16, color: Colors.primary),
                  Column(
                    crossAxis: CrossAxis.start,
                    children: [
                      Text(item['status'], style: Styles.labelMedium),
                      Text(
                        item['created_at'],
                        style: Styles.bodySmall,
                        color: Colors.secondaryText,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ---- 11. Wishlist ----
  app.page(
    'WishlistPage',
    route: '/wishlist',
    description: 'Saved products for the signed-in user.',
    state: {'wishlist': listOf(product), 'loading': bool_.withDefault(true)},
    onLoad: [
      ApiCall(
        getWishlist,
        params: {'token': AppState('authToken')},
        onSuccess: (res) => [
          SetState('wishlist', res['data']['wishlist']),
          SetState('loading', false),
        ],
        onFailure: [
          SetState('loading', false),
          Snackbar('Please sign in to view your wishlist.'),
        ],
      ),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Wishlist'),
      body: Container(
        color: Colors.primaryBackground,
        child: Column(
          children: [
            ProgressBar.circular(
              size: 30,
              thickness: 3,
              visible: State('loading'),
            ),
            Expanded(
              GridView(
                source: State('wishlist'),
                columns: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.62,
                padding: EdgeInsets.all(16),
                itemBuilder: (item) => productCard(
                  productName: item['name'],
                  price: item['price'],
                  image: item['image'],
                  badge: item['badge'],
                  onTapAction: Navigate(
                    'ProductDetailPage',
                    params: {'productId': item['id']},
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ---- 12. Profile ----
  app.page(
    'ProfilePage',
    route: '/profile',
    description: 'View/edit profile and logout.',
    state: {
      'fullName': string,
      'phone': string,
      'address': string,
    },
    onLoad: [
      SetState('fullName', AppState('userName')),
      SetState('phone', AppState('userPhone')),
      SetState('address', AppState('userAddress')),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Profile'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 20,
        child: Column(
          scrollable: true,
          crossAxis: CrossAxis.start,
          spacing: 14,
          children: [
            Row(
              spacing: 12,
              crossAxis: CrossAxis.center,
              children: [
                Icon('account_circle', size: 56, color: Colors.primary),
                Column(
                  crossAxis: CrossAxis.start,
                  children: [
                    Text(AppState('userName'), style: Styles.titleMedium),
                    Text(
                      AppState('userEmail'),
                      style: Styles.bodySmall,
                      color: Colors.secondaryText,
                    ),
                  ],
                ),
              ],
            ),
            Divider(),
            Text('Edit details', style: Styles.titleMedium),
            TextField(
              label: 'Full Name',
              onChanged: SetState('fullName', TextValue()),
            ),
            TextField(
              label: 'Phone',
              keyboard: Keyboard.number,
              onChanged: SetState('phone', TextValue()),
            ),
            TextField(
              label: 'Address',
              onChanged: SetState('address', TextValue()),
            ),
            Button(
              'Save Changes',
              width: double.infinity,
              height: 46,
              color: Colors.primary,
              textColor: Colors.primaryBackground,
              onTap: [
                ApiCall(
                  updateProfile,
                  params: {
                    'fullName': State('fullName'),
                    'phone': State('phone'),
                    'address': State('address'),
                    'token': AppState('authToken'),
                  },
                  onSuccess: (res) => [
                    UpdateAppState.set('userName', State('fullName')),
                    UpdateAppState.set('userPhone', State('phone')),
                    UpdateAppState.set('userAddress', State('address')),
                    Snackbar('Profile updated'),
                  ],
                  onFailure: [Snackbar('Update failed. Please sign in.')],
                ),
              ],
            ),
            Divider(),
            Button(
              'Logout',
              variant: ButtonVariant.outlined,
              width: double.infinity,
              height: 46,
              icon: 'logout',
              onTap: [
                ApiCall(
                  logoutUser,
                  params: {'token': AppState('authToken')},
                  onSuccess: (res) => [Snackbar('Signed out')],
                  onFailure: [Snackbar('Signed out')],
                ),
                UpdateAppState.set('authToken', ''),
                UpdateAppState.set('isLoggedIn', false),
                UpdateAppState.set('userName', ''),
                UpdateAppState.set('userEmail', ''),
                ClearAppState('cartItems'),
                Navigate('SplashPage'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// -- CLI boilerplate --
final class _CliOptions {
  const _CliOptions({
    this.apiKey,
    this.baseUrl,
    this.projectName,
    this.projectId,
    this.findOrCreate = false,
    this.allowNewProject = false,
    this.dryRun = false,
    this.commitMessage,
  });

  final String? apiKey;
  final String? baseUrl;
  final String? projectName;
  final String? projectId;
  final bool findOrCreate;
  final bool allowNewProject;
  final bool dryRun;
  final String? commitMessage;
}

_CliOptions _parseCliOptions(List<String> args) {
  String? apiKey;
  String? baseUrl;
  String? projectName;
  String? projectId;
  String? commitMessage;
  var findOrCreate = false;
  var allowNewProject = false;
  var dryRun = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--help':
      case '-h':
        _printUsage();
        exit(0);
      case '--api-key':
        apiKey = _requireValue(args, ++i, '--api-key');
      case '--base-url':
        baseUrl = _requireValue(args, ++i, '--base-url');
      case '--project-name':
        projectName = _requireValue(args, ++i, '--project-name');
      case '--project-id':
        projectId = _requireValue(args, ++i, '--project-id');
      case '--commit-message':
        commitMessage = _requireValue(args, ++i, '--commit-message');
      case '--find-or-create':
        findOrCreate = true;
      case '--allow-new-project':
        allowNewProject = true;
      case '--dry-run':
        dryRun = true;
      default:
        stderr.writeln('Unknown option: $arg');
        _printUsage();
        exit(64);
    }
  }

  return _CliOptions(
    apiKey: apiKey,
    baseUrl: baseUrl,
    projectName: projectName,
    projectId: projectId,
    findOrCreate: findOrCreate,
    allowNewProject: allowNewProject,
    dryRun: dryRun,
    commitMessage: commitMessage,
  );
}

String _requireValue(List<String> args, int index, String flag) {
  if (index >= args.length) {
    stderr.writeln('Missing value for $flag.');
    _printUsage();
    exit(64);
  }
  return args[index];
}

void _printUsage() {
  stdout.writeln('''
Build the SoleCraftPH mobile app in FlutterFlow.

Usage:
  dart run dsl/create.dart [options]
''');
}
