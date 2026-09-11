library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';
// Adding one field to an existing struct is not on the DSL surface —
// app.struct(...) re-declares the whole thing and throws on a field mismatch.
// ignore: implementation_imports
import 'package:flutterflow_ai/src/helpers/data_schema_helpers.dart'
    show addDataStructField, findDataStructField;
import 'package:fixnum/fixnum.dart' show Int64;
import 'package:solecraftfinal/flutterflow_project.dart' as ff;

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  try {
    await flutterFlowAI(
      buildStarterEditFlow,
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
Run the starter FlutterFlow AI edit flow.

Usage:
  dart run dsl/edit.dart [options]

Options:
  --api-key <key>           FlutterFlow API key. Defaults to FF_API_KEY.
  --base-url <url>          Override the FlutterFlow API base URL.
  --project-name <name>     Create a new project with this name.
  --project-id <id>         Push into an existing project by ID.
  --find-or-create          Retry by reusing a same-name project before creating.
  --allow-new-project       Bypass the workspace binding guard and create a different project.
  --commit-message <text>   Commit message for the push.
  --dry-run                 Compile and validate without pushing.
  --help, -h                Show this help.
''');
}

/// Buttons that sit beside something else in a Row, so they must not stretch.
/// Everything else in this app is a stacked full-width call to action.
const _inlineButtons = <String>{'markAllRead'};

/// One label/value line in the Order Detail summary card. Same edges and
/// baselines on every row, which is the whole point of pulling it out.
DslWidget _detailRow(String label, Object? value, {Object? visibleWhen}) => Row(
  mainAxis: MainAxis.spaceBetween,
  crossAxis: CrossAxis.start,
  spacing: 12,
  visible: visibleWhen,
  children: [
    Text(label, style: Styles.bodySmall, color: Colors.secondaryText),
    Text(value, style: Styles.bodyMedium),
  ],
);

/// The wishlist heart's tap chain. Two icons share it — a hollow one and a
/// filled one, swapped by visibility — so both must do exactly the same thing.
/// The server's answer drives the state, never a local guess at the new value.
List<DslAction> _toggleHeart(Endpoint toggle, String outputName) => [
  ApiCall(
    toggle,
    outputAs: outputName,
    params: {
      'token': AppState(ff.AppState.authToken),
      'product_id': PageParam('id'),
    },
    onSuccess:
        (res) => [
          SetState(ff.Pages.shoeDetails.state.wishlisted, res['wishlisted']),
        ],
    onFailure: [Snackbar('Sign in to save shoes to your wishlist.')],
  ),
];

/// Cart sync: the on-device bag becomes a cache of a server-side cart, so the
/// website and the app show the same items for a signed-in shopper.
///
/// Shape of the sync:
/// - every local bag mutation pushes the WHOLE bag to `?action=replace`, and
///   the server's answer is written back over the bag. One call, no drift.
/// - the Bag page pulls on load, which is how a cart filled on the website
///   reaches the phone.
/// - signed out, nothing is pushed and the bag stays purely local.
///
/// The Checkout chain is deliberately untouched: `api/orders.php` clears the
/// server cart itself once an order is created, so there is nothing for the
/// app to remember to do.
void buildStarterEditFlow(App app) {
  // ---------------------------------------------------------------------------
  // 0. Theme — the website's own tokens, so the two feel like one brand
  // ---------------------------------------------------------------------------
  // Straight from public_html/assets/css/style.css:
  //   --ink #111111  --paper #FAF9F6  --stone #EDEAE3  --gray #8A8578  --blaze #E2412A
  // The app shipped with FlutterFlow's stock slate/orange palette, which shares
  // nothing with the storefront.
  app.themeColor('primary', 0xFF111111); // ink — buttons and headings
  app.themeColor('secondary', 0xFFE2412A); // blaze — the one accent
  app.themeColor('tertiary', 0xFF8A8578); // gray
  app.themeColor('alternate', 0xFFEDEAE3); // stone — rules and dividers
  app.themeColor('primaryText', 0xFF111111);
  app.themeColor('secondaryText', 0xFF8A8578);
  app.themeColor('primaryBackground', 0xFFFAF9F6); // paper
  app.themeColor('secondaryBackground', 0xFFFFFFFF);
  app.themeColor('accent1', 0xFFE2412A);
  app.themeColor('accent2', 0xFFEDEAE3);
  app.themeColor('accent3', 0xFF8A8578);
  app.themeColor('accent4', 0xFFFFFFFF);
  // The storefront has exactly one red and uses it for both accent and
  // destructive text, so error matches rather than inventing a second red.
  app.themeColor('error', 0xFFE2412A);
  // No green/amber/blue exists in the site's CSS. These are muted to sit with
  // the warm neutrals instead of leaving FlutterFlow's bright defaults in place.
  app.themeColor('success', 0xFF2F6B4F);
  app.themeColor('warning', 0xFFB07A18);
  app.themeColor('info', 0xFF4A4A44);
  app.primaryFont('Inter'); // the site's body face

  // ---------------------------------------------------------------------------
  // 0b. One button spec
  // ---------------------------------------------------------------------------
  // Buttons had grown five heights (48/50/52/56/64) and four corner radii
  // (6/8/10/12), picked per screen. Every Button on every page now gets the
  // same height and radius. IconButtons are left alone — they are a different
  // control and sizing them here would squash the bag's remove icon.
  const buttonHeight = 52;
  const buttonRadius = 12;
  for (final pageHandle in <ProjectPageHandle>[
    ff.Pages.account,
    ff.Pages.bag,
    ff.Pages.checkout,
    ff.Pages.confirmed,
    ff.Pages.myOrders,
    ff.Pages.payment,
    ff.Pages.register,
    ff.Pages.shoeDetails,
    ff.Pages.signIn,
    // The screens added today. Left out of the first pass, which is why the
    // Notifications button sat at its authored size and clipped its label.
    ff.Pages.orderDetail,
    ff.Pages.profile,
    ff.Pages.notifications,
    ff.Pages.wishlist,
    ff.Pages.reviews,
    ff.Pages.help,
    ff.Pages.infoPage,
  ]) {
    final buttons =
        pageHandle.widgets.all.where((w) => w.type == 'Button').toList();
    if (buttons.isEmpty) continue;
    app.editPage(pageHandle, (page) {
      for (final button in buttons) {
        page.update(pageHandle.widgets.byKey(button.key).single, (patch) {
          // Width AND height, every time. size() writes both fields, so passing
          // height alone nulls the width — which is how the first pass silently
          // stripped `width: double.infinity` from every existing CTA and left
          // them shrink-wrapped around their labels.
          patch.size(
            width: _inlineButtons.contains(button.name) ? 150 : double.infinity,
            height: buttonHeight,
          );
          patch.borderRadius(buttonRadius);
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 1. Response shape for /api/cart.php
  // ---------------------------------------------------------------------------
  // `items` is a list of the existing BagItem struct — the endpoint emits `id`
  // alongside `product_id` precisely so the response drops straight into
  // AppState.bag with no translation.
  final cartResponse = app.struct(
    'CartResponse',
    {
      'items': listOf(ff.Structs.bagItem),
      'count': int_,
      'subtotal': double_,
      'shipping': double_,
      'total': double_,
    },
    description: 'The signed-in shopper\'s server-side cart, plus its totals.',
  );

  // ---------------------------------------------------------------------------
  // 2. Endpoints — added to the existing "Api" group
  // ---------------------------------------------------------------------------
  // The group is re-declared with its current base URL and shared headers so
  // the ensure matches; the nine endpoints already on it are left alone.
  final cartGet = Endpoint.get(
    'CartGet',
    '/cart.php',
    variables: {'token': string},
    headers: {'Authorization': 'Bearer [token]'},
    response: cartResponse,
  );
  final cartReplace = Endpoint.post(
    'CartReplace',
    '/cart.php?action=replace',
    variables: {'token': string, 'items': json},
    headers: {'Authorization': 'Bearer [token]'},
    body: const {'items': '<items>'},
    response: cartResponse,
  );

  // A union rather than a replace, called once at sign-in so a bag built while
  // signed out survives without wiping a cart filled on the website.
  final cartMerge = Endpoint.post(
    'CartMerge',
    '/cart.php?action=merge',
    variables: {'token': string, 'items': json},
    headers: {'Authorization': 'Bearer [token]'},
    body: const {'items': '<items>'},
    response: cartResponse,
  );

  // Login and Register are restated exactly as they already exist on the group —
  // ensureEndpointInGroup no-ops on an identical payload — because ApiCall needs
  // the Endpoint object to rebuild their action chains below.
  final login = Endpoint.post(
    'Login',
    '/auth.php?action=login',
    variables: {'login': string, 'password': string},
    body: const {'username': '<login>', 'password': '<password>'},
    response: ff.Structs.authResponse,
  );
  final register = Endpoint.post(
    'Register',
    '/auth.php?action=register',
    variables: {
      'username': string,
      'email': string,
      'password': string,
      'full_name': string,
    },
    body: const {
      'username': '<username>',
      'email': '<email>',
      'password': '<password>',
      'full_name': '<full_name>',
    },
    response: ff.Structs.authResponse,
  );

  // Also restated as-is, so the Checkout chain can be rebuilt around it below.
  final createOrder = Endpoint.post(
    'CreateOrder',
    '/orders.php',
    variables: {
      'token': string,
      'name': string,
      'email': string,
      'phone': string,
      'address': string,
      'payment': string,
      'items': json,
    },
    headers: {'Authorization': 'Bearer [token]'},
    body: const {
      'customer': {
        'name': '<name>',
        'email': '<email>',
        'phone': '<phone>',
        'address': '<address>',
        'payment_method': '<payment>',
      },
      'items': '<items>',
    },
    response: ff.Structs.orderCreated,
  );

  // ---------------------------------------------------------------------------
  // 21. Carrying the pin onto the order
  // ---------------------------------------------------------------------------
  // The pin was saved against the address and stopped there — orders only ever
  // got the address text, so a customer could place their house on the map and
  // the admin order page would show nothing to open. orders now has
  // latitude/longitude columns; this is what fills them.
  //
  // A second endpoint rather than two more variables on CreateOrder, for the
  // same reason as GetProductsFiltered: endpoints are create-if-missing, and
  // changing one's shape throws on every rerun.
  final createOrderPinned = Endpoint.post(
    'CreateOrderPinned',
    '/orders.php',
    variables: {
      'token': string,
      'name': string,
      'email': string,
      'phone': string,
      'address': string,
      'payment': string,
      'latitude': string,
      'longitude': string,
      'items': json,
    },
    headers: {'Authorization': 'Bearer [token]'},
    body: const {
      'customer': {
        'name': '<name>',
        'email': '<email>',
        'phone': '<phone>',
        'address': '<address>',
        'payment_method': '<payment>',
        // Empty strings when the chosen address has no pin, which order_create
        // reads as "no coordinates" rather than as a point off West Africa.
        'latitude': '<latitude>',
        'longitude': '<longitude>',
      },
      'items': '<items>',
    },
    response: ff.Structs.orderCreated,
  );

  // Confirmed reads the order back through GetOrder, which now needs a token —
  // api/orders.php refuses to answer on the order id alone. Declared with the
  // token so the validator can see the variable the page passes.
  final getOrder = Endpoint.get(
    'GetOrder',
    '/orders.php?id=[id]',
    variables: {'id': int_, 'token': string},
    headers: {'Authorization': 'Bearer [token]'},
    response: ff.Structs.orderRow,
  );

  // ---------------------------------------------------------------------------
  // 7b. Order Detail — the tap-through MyOrders never had
  // ---------------------------------------------------------------------------
  // api/orders.php returns the order, its lines and (new) its status history.
  // GetOrder stays as it is so the Confirmed page keeps its lean OrderRow shape;
  // this is a second call against the same URL with the fuller struct.
  final orderLine = app.struct('OrderLine', {
    'product_name': string,
    'size': string,
    'unit_price': string,
    'quantity': int_,
    'subtotal': string,
  }, description: 'One line of an order: product, size, quantity, money.');

  final orderEvent = app.struct('OrderEvent', {
    'status': string,
    'note': string,
    'created_at': string,
  }, description: 'One entry in an order\'s tracking history.');

  final orderFull = app.struct('OrderFull', {
    'id': int_,
    'created_at': string,
    'customer_name': string,
    'customer_phone': string,
    'customer_address': string,
    'payment_method': string,
    'payment_status': string,
    'status': string,
    'tracking_number': string,
    'total_amount': string,
    'items': listOf(orderLine),
    'status_history': listOf(orderEvent),
  }, description: 'A single order with its lines and tracking history.');

  final getOrderDetail = Endpoint.get(
    'GetOrderDetail',
    '/orders.php?id=[id]',
    variables: {'id': int_, 'token': string},
    headers: {'Authorization': 'Bearer [token]'},
    response: orderFull,
  );

  // --- Profile ---------------------------------------------------------------
  final profileStruct = app.struct('Profile', {
    'id': int_,
    'username': string,
    'email': string,
    'full_name': string,
    'phone': string,
    'address': string,
    'role': string,
  }, description: 'The signed-in shopper\'s account details.');

  final profileSaved = app.struct('ProfileSaved', {
    'message': string,
    'profile': profileStruct,
  }, description: 'Result of saving profile details.');

  final apiMessage = app.struct('ApiMessage', {
    'message': string,
  }, description: 'A bare success message from the API.');

  final getProfile = Endpoint.get(
    'GetProfile',
    '/profile.php',
    variables: {'token': string},
    headers: {'Authorization': 'Bearer [token]'},
    response: profileStruct,
  );
  final updateProfile = Endpoint.post(
    'UpdateProfile',
    '/profile.php?action=update',
    variables: {
      'token': string,
      'full_name': string,
      'phone': string,
      'address': string,
    },
    headers: {'Authorization': 'Bearer [token]'},
    body: const {
      'full_name': '<full_name>',
      'phone': '<phone>',
      'address': '<address>',
    },
    response: profileSaved,
  );
  final changePassword = Endpoint.post(
    'ChangePassword',
    '/profile.php?action=password',
    variables: {
      'token': string,
      'current_password': string,
      'new_password': string,
    },
    headers: {'Authorization': 'Bearer [token]'},
    body: const {
      'current_password': '<current_password>',
      'new_password': '<new_password>',
    },
    response: apiMessage,
  );

  // --- Notifications ----------------------------------------------------------
  final notificationRow = app.struct('NotificationRow', {
    'id': int_,
    'title': string,
    'message': string,
    'is_read': bool_,
    'created_at': string,
  }, description: 'One notification: order updates and announcements.');

  final notificationList = app.struct('NotificationList', {
    'items': listOf(notificationRow),
    'count': int_,
    'unread': int_,
  }, description: 'The signed-in shopper\'s notifications, newest first.');

  final getNotifications = Endpoint.get(
    'GetNotifications',
    '/notifications.php',
    variables: {'token': string},
    headers: {'Authorization': 'Bearer [token]'},
    response: notificationList,
  );
  final markNotificationsRead = Endpoint.post(
    'MarkNotificationsRead',
    '/notifications.php?action=read',
    variables: {'token': string},
    headers: {'Authorization': 'Bearer [token]'},
    response: notificationList,
  );

  // --- Wishlist ---------------------------------------------------------------
  // Rows arrive as full product rows, so the existing Shoe struct and ShoeCard
  // component read them unchanged.
  final wishlist = app.struct('Wishlist', {
    'items': listOf(ff.Structs.shoe),
    'count': int_,
  }, description: 'Products the signed-in shopper has saved.');

  final wishlistToggled = app.struct('WishlistToggled', {
    'wishlisted': bool_,
    'items': listOf(ff.Structs.shoe),
    'count': int_,
  }, description: 'Result of saving or unsaving one product.');

  final getWishlist = Endpoint.get(
    'GetWishlist',
    '/wishlist.php',
    variables: {'token': string},
    headers: {'Authorization': 'Bearer [token]'},
    response: wishlist,
  );
  // Restated so ShoeDetails' page-load chain can be rebuilt around it.
  final getProduct = Endpoint.get(
    'GetProduct',
    '/products.php?id=[id]',
    variables: {'id': int_},
    response: ff.Structs.shoe,
  );

  final wishlistFlag = app.struct('WishlistFlag', {
    'wishlisted': bool_,
  }, description: 'Whether one product is on the shopper\'s wishlist.');

  final wishlistHas = Endpoint.get(
    'WishlistHas',
    '/wishlist.php?product_id=[product_id]',
    variables: {'token': string, 'product_id': int_},
    headers: {'Authorization': 'Bearer [token]'},
    response: wishlistFlag,
  );
  final toggleWishlist = Endpoint.post(
    'ToggleWishlist',
    '/wishlist.php?action=toggle',
    variables: {'token': string, 'product_id': int_},
    headers: {'Authorization': 'Bearer [token]'},
    body: const {'product_id': '<product_id>'},
    response: wishlistToggled,
  );

  // --- Reviews ----------------------------------------------------------------
  final reviewRow = app.struct('ReviewRow', {
    'id': int_,
    'username': string,
    'rating': int_,
    'comment': string,
    'created_at': string,
  }, description: 'One approved customer review.');

  final reviewFeed = app.struct('ReviewFeed', {
    'items': listOf(reviewRow),
    'count': int_,
    'average': double_,
    // Whether THIS shopper may write one: signed in, has ordered it, and has
    // not reviewed it yet. The server decides; the app only renders.
    'can_review': bool_,
    'has_reviewed': bool_,
    'has_purchased': bool_,
  }, description: 'Reviews for one product, plus what the viewer may do.');

  final getReviews = Endpoint.get(
    'GetReviews',
    '/reviews.php?product_id=[product_id]',
    variables: {'token': string, 'product_id': int_},
    headers: {'Authorization': 'Bearer [token]'},
    response: reviewFeed,
  );
  final createReview = Endpoint.post(
    'CreateReview',
    '/reviews.php?action=create',
    variables: {
      'token': string,
      'product_id': int_,
      // A Dropdown hands back a String, and PHP casts it on the way in.
      // Declaring int_ here makes the compiler reject the binding outright.
      'rating': string,
      'comment': string,
    },
    headers: {'Authorization': 'Bearer [token]'},
    body: const {
      'product_id': '<product_id>',
      'rating': '<rating>',
      'comment': '<comment>',
    },
    response: reviewFeed,
  );

  // --- Help & Info ------------------------------------------------------------
  final infoPageRow = app.struct('InfoPageRow', {
    'slug': string,
    'title': string,
  }, description: 'One entry in the About / FAQ / Privacy menu.');

  final infoMenu = app.struct('InfoMenu', {
    'items': listOf(infoPageRow),
    'count': int_,
  }, description: 'The CMS pages available to read in the app.');

  final infoPage = app.struct('InfoPage', {
    'slug': string,
    'title': string,
    'content': string,
  }, description: 'One CMS page with its body text.');

  final apiNote = app.struct('ApiNote', {
    'message': string,
  }, description: 'A plain confirmation message from the API.');

  final getInfoPages = Endpoint.get(
    'GetInfoPages',
    '/support.php',
    response: infoMenu,
  );
  final getInfoPage = Endpoint.get(
    'GetInfoPage',
    '/support.php?slug=[slug]',
    variables: {'slug': string},
    response: infoPage,
  );
  final sendContact = Endpoint.post(
    'SendContact',
    '/support.php?action=contact',
    variables: {
      'token': string,
      'name': string,
      'email': string,
      'subject': string,
      'message': string,
    },
    headers: {'Authorization': 'Bearer [token]'},
    body: const {
      'name': '<name>',
      'email': '<email>',
      'subject': '<subject>',
      'message': '<message>',
    },
    response: apiNote,
  );

  // Telling an expired token apart from a flat connection needs the HTTP
  // status, or the body of the call that failed. The action DSL can read
  // neither — only the parsed body of a call that succeeded. So the question
  // gets asked of an endpoint that always succeeds and puts the answer in its
  // body: /auth.php?action=session, which exists for exactly this.
  final sessionCheck = app.struct('SessionCheck', {
    'valid': bool_,
  }, description: 'Whether the stored API token is still good.');
  final authSession = Endpoint.get(
    'AuthSession',
    '/auth.php?action=session',
    variables: {'token': string},
    headers: {'Authorization': 'Bearer [token]'},
    response: sessionCheck,
  );

  // Which payment methods are switched on, and which categories have anything
  // in them. The app hardcoded all four, so turning GCash off in admin took it
  // off the website and left it on the phone.
  final storeSettings = app.struct('StoreSettings', {
    'cod': bool_,
    'gcash': bool_,
    'card': bool_,
    'categories': listOf(string),
  }, description: 'Storefront switches the app used to hardcode.');
  final getSettings = Endpoint.get(
    'GetSettings',
    '/settings.php',
    response: storeSettings,
  );

  // Already on the group — restated only so Shop's page load can be rewritten
  // to record a failure instead of leaving an empty grid behind.
  final getProducts = Endpoint.get(
    'GetProducts',
    '/products.php?category=[category]&q=[q]',
    variables: {'category': string, 'q': string},
    response: ff.Structs.catalogResponse,
  );

  // A second products endpoint rather than a subcategory parameter on the
  // first: endpoints, like structs, are create-if-missing, so changing
  // GetProducts' shape throws on every rerun. GetProducts stays for the
  // unfiltered shop load; this one carries the category drill-down.
  final getProductsFiltered = Endpoint.get(
    'GetProductsFiltered',
    '/products.php?category=[category]&subcategory=[subcategory]&q=[q]',
    variables: {'category': string, 'subcategory': string, 'q': string},
    response: ff.Structs.catalogResponse,
  );

  // Already on the group, restated for the same reason as GetProducts: its
  // page load had no failure branch at all and needed rewriting.
  final myOrdersList = Endpoint.get(
    'MyOrders',
    '/my_orders.php',
    variables: {'token': string},
    headers: {'Authorization': 'Bearer [token]'},
    response: ff.Structs.myOrdersResponse,
  );

  // Defaults are all true: a shop that cannot reach settings.php should show
  // every payment method rather than none, and the server refuses a disabled
  // one anyway.
  app.state('payCod', bool_.withDefault(true));
  app.state('payGcash', bool_.withDefault(true));
  app.state('payCard', bool_.withDefault(true));
  app.state('shopCategories', listOf(string));

  // ---------------------------------------------------------------------------
  // 15. Push notifications
  // ---------------------------------------------------------------------------
  // The bell only ever showed what was in the notifications table, which meant
  // "your order shipped" reached whoever happened to open the app. The server
  // now pushes from notification_notify_customer(), the one function every
  // customer notification already went through — it just needs to know which
  // devices to send to.
  final registerDevice = Endpoint.post(
    'RegisterDevice',
    '/devices.php?action=register',
    variables: {'token': string, 'device_token': string, 'platform': string},
    headers: {'Authorization': 'Bearer [token]'},
    body: const {'token': '<device_token>', 'platform': '<platform>'},
    response: app.struct('DeviceRegistered', {
      'registered': bool_,
    }, description: 'Whether this device will receive order updates.'),
  );

  // Depended on explicitly rather than inherited from FlutterFlow's push
  // system, which is switched off. That system sends through a Cloud Function
  // and keys device tokens to a Firebase Auth user in Firestore — none of
  // which this app has, and enabling it generated a serialization helper that
  // imports cloud_firestore and so would not compile. The server sends
  // straight to FCM instead; all the app needs is a token and the OS.
  app.pubDependency('firebase_messaging', '15.2.7');

  // Asking for the token also asks for the notification permission, which is
  // the moment Android wants a reason on screen — so this runs from Shop,
  // after the store has drawn, rather than cold at launch.
  final deviceToken = app.customAction(
    'deviceToken',
    args: const <String, DslType>{},
    returns: string,
    code: r'''
import 'package:firebase_messaging/firebase_messaging.dart';

Future<String> deviceToken() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return '';
    }
    return await messaging.getToken() ?? '';
  } catch (_) {
    // No Firebase config, no Play Services, permission dialog dismissed —
    // none of it is worth interrupting the shopper over.
    return '';
  }
}
''',
    description: 'This device\'s FCM token, or empty if push is unavailable.',
  );

  // ---------------------------------------------------------------------------
  // 18. The second level of categories
  // ---------------------------------------------------------------------------
  // The website drills down — pick Athletic & Performance Footwear and a second
  // row of Road Running / Trail Running / Training & Gym appears. The app had
  // three top-level chips and stopped, even though /api/products.php has always
  // accepted ?subcategory=.
  //
  // Served by its own endpoint rather than added to StoreSettings: app.struct
  // is create-if-missing, so adding a field to a struct that already exists in
  // the project throws on the next run.
  final taxonomyRow = app.struct('TaxonomyRow', {
    'category': string,
    'subcategory': string,
  }, description: 'One category / subcategory pair that has stock behind it.');
  final taxonomyList = app.struct('TaxonomyList', {
    'count': int_,
    'items': listOf(taxonomyRow),
  }, description: 'Every category / subcategory pair the shop can sell.');
  final getTaxonomy = Endpoint.get(
    'GetTaxonomy',
    '/settings.php?action=taxonomy',
    response: taxonomyList,
  );

  // The subcategories of one category, as a plain list the chip row can repeat
  // over. Returns nothing for an empty category, which is what hides the row.

  // Every category this shop sells has an ampersand in its name — "Athletic &
  // Performance Footwear" — and FlutterFlow builds a request URL by plain
  // string interpolation:
  //
  //     '${baseUrl}/products.php?category=${category}&q=${q}'
  //
  // So the & inside the value ended the parameter. The server received
  // category="Athletic " plus a stray parameter called "Performance Footwear",
  // matched nothing, and returned an empty grid. Encoded, the same request
  // returns all fifteen shoes. This has been broken since the chips were first
  // wired; the subcategory work only made it visible.
  final urlSafe = app.customFunction(
    'urlSafe',
    args: {'value': string},
    returns: string,
    code: r'''
return Uri.encodeQueryComponent(value ?? '');
''',
    description:
        'Percent-encodes a value so it survives being pasted into a query string.',
  );
  final subcategoriesOf = app.customFunction(
    'subcategoriesOf',
    args: {'rows': listOf(taxonomyRow), 'category': string},
    returns: listOf(string),
    code: r'''
final wanted = category ?? '';
if (wanted.isEmpty) return <String>[];
return (rows ?? <TaxonomyRowStruct>[])
    .where((r) => (r.category ?? '') == wanted)
    .map((r) => r.subcategory ?? '')
    .where((s) => s.isNotEmpty)
    .toList();
''',
    description: 'The subcategories belonging to one category.',
  );

  final addressRow = app.struct('AddressRow', {
    'id': int_,
    'label': string,
    'recipient_name': string,
    'phone': string,
    'address': string,
    // Strings, not doubles: they are only ever displayed or handed back to
    // the server, and a JSON double renders as 14.599512000000001 on some
    // devices. Empty when this address has no pin.
    'latitude': string,
    'longitude': string,
    'is_default': bool_,
    'map_url': string,
  }, description: 'One saved delivery address.');
  final addressList = app.struct('AddressList', {
    'count': int_,
    'items': listOf(addressRow),
  }, description: 'Every address the signed-in shopper has saved.');

  final getAddresses = Endpoint.get(
    'GetAddresses',
    '/addresses.php',
    variables: {'token': string},
    headers: {'Authorization': 'Bearer [token]'},
    response: addressList,
  );
  // Every write answers with the whole list, so the screen never has to
  // re-fetch to show the result of what it just did.
  final saveAddress = Endpoint.post(
    'SaveAddress',
    '/addresses.php?action=save',
    variables: {
      'token': string,
      'id': int_,
      'label': string,
      'recipient_name': string,
      'phone': string,
      'address': string,
      'latitude': string,
      'longitude': string,
    },
    headers: {'Authorization': 'Bearer [token]'},
    body: const {
      'id': '<id>',
      'label': '<label>',
      'recipient_name': '<recipient_name>',
      'phone': '<phone>',
      'address': '<address>',
      'latitude': '<latitude>',
      'longitude': '<longitude>',
    },
    response: addressList,
  );
  final deleteAddress = Endpoint.post(
    'DeleteAddress',
    '/addresses.php?action=delete',
    variables: {'token': string, 'id': int_},
    headers: {'Authorization': 'Bearer [token]'},
    body: const {'id': '<id>'},
    response: addressList,
  );
  final defaultAddress = Endpoint.post(
    'DefaultAddress',
    '/addresses.php?action=default',
    variables: {'token': string, 'id': int_},
    headers: {'Authorization': 'Bearer [token]'},
    body: const {'id': '<id>'},
    response: addressList,
  );

  // ---------------------------------------------------------------------------
  // The map pin, Shopee-style
  // ---------------------------------------------------------------------------
  // A pin fixed dead centre while the map moves underneath it, and the address
  // resolved from wherever it lands. Three packages, none of which needs a key
  // or a card:
  //
  //  - flutter_map draws tiles on Flutter's own canvas. google_maps_flutter
  //    would put an Android platform view inside a modal bottom sheet, which is
  //    the one place that seam reliably shows — stutter on the open animation,
  //    z-order artifacts over the confirm card. Raster tiles lose a little
  //    polish on pinch-zoom against Google's vector ones; a picker is mostly
  //    panning, so that is the cheap half to give up.
  //  - latlong2 is flutter_map's coordinate type. Not optional, not ours.
  //  - geocoding turns the pin back into words through Android's own Geocoder.
  //    Free, no key, and independent of whose tiles are underneath — so the
  //    autofill survives changing basemaps later.
  app.pubDependency('flutter_map', '7.0.2');
  app.pubDependency('latlong2', '0.9.1');
  app.pubDependency('geocoding', '3.0.0');

  // How the sheet hands its answer back to whichever screen opened it.
  //
  // A custom widget cannot return a value: callbacks on this SDK are
  // `ActionType` with no arguments, so they can fire but cannot carry a
  // latitude. App state is the way across that boundary. Two plain strings —
  // deliberately not a struct, because a list-of-struct app state field sets
  // its isList flag after creation and then fails every later run on a shape
  // mismatch, which is why `taxonomy` above is written but never re-declared.
  //
  // Not persisted. These are scratch space for one pin-drop; the saved copy
  // lives on the address row where it belongs.
  app.state(
    'draftPin',
    string.withDefault(''),
    description: 'Pin picked in the map sheet, "lat,lng". Empty when unset.',
  );
  app.state(
    'draftPinText',
    string.withDefault(''),
    description: 'Address the map sheet reverse-geocoded for draftPin.',
  );

  // Where the phone is, as "lat,lng" — or empty when it cannot be had. One
  // string rather than two outputs because an action can only produce one
  // value, and half a coordinate is worse than none.
  app.pubDependency('geolocator', '13.0.2');
  final currentPin = app.customAction(
    'currentPin',
    args: const <String, DslType>{},
    returns: string,
    code: r'''
import 'package:geolocator/geolocator.dart';

Future<String> currentPin() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return '';
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return '';
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return '${position.latitude},${position.longitude}';
  } catch (_) {
    // Location off, permission refused, no fix in fifteen seconds — none of
    // it is worth an error in a shopper's face. They can still type.
    return '';
  }
}
''',
    description: 'This device\'s coordinates as "lat,lng", or empty.',
  );

  // Splitting the pin back apart for the two fields the API wants.
  final pinPart = app.customFunction(
    'pinPart',
    args: {'pin': string, 'index': int_},
    returns: string,
    code: r'''
final parts = (pin ?? '').split(',');
final i = index ?? 0;
if (parts.length != 2) return '';
return parts[i].trim();
''',
    description: 'Latitude (0) or longitude (1) out of a "lat,lng" pin.',
  );

  // The inverse, for loading a saved address back into the form. Empty when
  // either half is missing, because half a coordinate points at the Gulf of
  // Guinea rather than at nothing.
  final joinPin = app.customFunction(
    'joinPin',
    args: {'lat': string, 'lng': string},
    returns: string,
    code: r'''
final a = (lat ?? '').trim();
final b = (lng ?? '').trim();
if (a.isEmpty || b.isEmpty) return '';
return '$a,$b';
''',
    description: 'Latitude and longitude back into one "lat,lng" pin.',
  );

  // The map itself. Typechecked against the real generated types in
  // .ffai_staging before it was pasted here — FFAppState, FlutterFlowTheme and
  // currentPin() are all resolved there, which the DSL's own validators cannot
  // see.
  //
  // The actions import below is redundant — FlutterFlow's automatic header for
  // a custom widget already pulls in /custom_code/actions/index.dart, so the
  // generated file carries it twice. It was kept because app.customWidget is
  // create-if-missing on an exact payload match and deleting it would have
  // broken every rerun. That constraint is gone now the widget goes through
  // updateCustomWidget below, so the line can be dropped whenever someone is
  // touching this widget for another reason — not bundled into a fix that has
  // to land.
  final pinMapParams = <String, DslType>{
    'startPin': string.withDefault(''),
    'tileUrl': string.withDefault(''),
    'attribution': string.withDefault(''),
  };
  const pinMapDescription =
      'Map with a pin fixed at centre. Publishes draftPin / draftPinText.';
  final pinMapCode = r'''
import '/custom_code/actions/index.dart'; // currentPin()

import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
// Prefixed deliberately. flutter_flow_util re-exports FlutterFlow's own
// lat_lng.dart, which declares a LatLng of its own; unprefixed, every
// coordinate in this file would be ambiguous.
import 'package:latlong2/latlong.dart' as ll;

/// A map with a pin fixed dead centre, the way Shopee does it.
///
/// The pin never moves — the map moves underneath it. That is not a stylistic
/// choice: a draggable marker has to be hit-tested, kept in sync with the
/// camera, and fought with when it lands under your thumb. A centred icon
/// painted over the map has none of those problems and reads as more precise,
/// because the target is always the exact middle of the screen.
///
/// Publishes to app state rather than returning a value: a FlutterFlow custom
/// widget's callbacks take no arguments, so there is no way to hand a
/// coordinate back up. `draftPin` carries "lat,lng"; `draftPinText` carries the
/// reverse-geocoded line, or empty while it is being looked up.
class PinMap extends StatefulWidget {
  const PinMap({
    super.key,
    this.width,
    this.height,
    this.startPin,
    this.tileUrl,
    this.attribution,
  });

  final double? width;
  final double? height;

  /// Where to open, as "lat,lng". Empty or unparseable falls back to Manila.
  final String? startPin;

  /// Tile template. Passed in rather than baked so the basemap can be swapped
  /// without touching this file.
  final String? tileUrl;

  /// Credit line for the tile source. Every free tile provider requires one.
  final String? attribution;

  @override
  State<PinMap> createState() => _PinMapState();
}

class _PinMapState extends State<PinMap> {
  /// Rizal Park. Only ever seen by someone whose location is off *and* who has
  /// no saved pin — somewhere in the country beats the middle of the ocean,
  /// which is where a (0,0) fallback would put them.
  static const _manila = ll.LatLng(14.5995, 120.9842);

  static const _defaultZoom = 17.0;

  final _map = MapController();

  late ll.LatLng _centre;

  /// Cancelled and restarted on every camera frame; only the pause at the end
  /// of a drag survives it.
  Timer? _settle;

  bool _dragging = false;

  /// Guards against an out-of-order geocode: drag, pause, drag again quickly
  /// and the first lookup can land after the second, labelling the new pin
  /// with the old address.
  int _lookup = 0;

  @override
  void initState() {
    super.initState();
    _centre = _parsePin(widget.startPin) ?? _manila;
    // Confirming without touching the map has to work, so publish the opening
    // position now rather than waiting for a gesture that may never come.
    WidgetsBinding.instance.addPostFrameCallback((_) => _publish(_centre));
  }

  @override
  void dispose() {
    _settle?.cancel();
    _map.dispose();
    super.dispose();
  }

  /// "14.5995,120.9842" -> a point, or null if it is anything else.
  static ll.LatLng? _parsePin(String? pin) {
    final parts = (pin ?? '').split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    // Out of range means a bad parse, not a bad address. Opening the map on an
    // impossible coordinate throws inside flutter_map.
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return ll.LatLng(lat, lng);
  }

  /// Six decimals is about 11cm — past the point any phone GPS can tell apart,
  /// and short enough to read in the admin order view.
  static String _format(ll.LatLng at) =>
      '${at.latitude.toStringAsFixed(6)},${at.longitude.toStringAsFixed(6)}';

  /// Google Plus Codes, which Android's geocoder hands back as the street when
  /// there is no named road at the pin — "M4F6+977" on its own, or
  /// "M4C4+GXR Permaline Homes" when it knows the place but not the road.
  ///
  /// A rider cannot deliver to a Plus Code, and two of the addresses already
  /// saved on this account were exactly that. Stripping it leaves either a
  /// real place name or nothing, and nothing is the honest answer.
  ///
  /// Safe against false positives: the alphabet below is Google's own twenty
  /// characters, chosen so the codes cannot spell words — every vowel is
  /// excluded. A Philippine street name needs a vowel, and none contains '+'.
  static final RegExp _plusCode = RegExp(
    r'^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,3}\b[\s,]*',
  );

  /// Philippine reading order: house/street, barangay, city, province.
  static String _composeAddress(Placemark p) {
    final seen = <String>{};
    final kept = <String>[];
    for (final raw in [
      p.street,
      p.subLocality,
      p.locality,
      p.administrativeArea,
    ]) {
      final value = (raw ?? '').replaceFirst(_plusCode, '').trim();
      // The platform geocoder repeats itself constantly — `street` often
      // already carries the barangay, and for a chartered city `locality` and
      // `administrativeArea` are the same word. Duplicates read as broken.
      //
      // A field that held nothing but a Plus Code is empty by now and drops
      // out here. If every field does, this returns '' — which the caller
      // already treats as "the lookup found nothing" and leaves whatever the
      // customer typed alone, rather than overwriting it with a code.
      if (value.isEmpty || !seen.add(value.toLowerCase())) continue;
      kept.add(value);
    }
    return kept.join(', ');
  }

  /// Writes the pin immediately and the address when it arrives.
  Future<void> _publish(ll.LatLng at) async {
    final token = ++_lookup;

    FFAppState().update(() {
      FFAppState().draftPin = _format(at);
      // Cleared on purpose. Leaving the previous line up would attribute one
      // place's address to another place's pin for as long as the lookup takes
      // — a brief "Finding address..." is the honest version.
      FFAppState().draftPinText = '';
    });

    var line = '';
    try {
      final places = await placemarkFromCoordinates(at.latitude, at.longitude);
      if (places.isNotEmpty) line = _composeAddress(places.first);
    } catch (_) {
      // No Play Services, no network, or nothing named within range. The pin
      // is still perfectly good and the rider only ever needed that — the
      // customer types the rest, exactly as they do today.
    }

    if (!mounted || token != _lookup) return;
    FFAppState().update(() => FFAppState().draftPinText = line);
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _centre = camera.center;
    // Programmatic moves publish themselves; only a finger starts the timer.
    if (!hasGesture) return;

    if (!_dragging) setState(() => _dragging = true);
    _settle?.cancel();
    // Geocoding every camera frame would hammer the platform channel and make
    // the label strobe. The pause at the end of a drag is the only moment that
    // carries any intent.
    _settle = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _dragging = false);
      _publish(_centre);
    });
  }

  Future<void> _recentre() async {
    // Reuses the existing custom action rather than calling Geolocator again
    // here — the permission handling and the fifteen-second timeout already
    // live there, and two copies would drift.
    final at = _parsePin(await currentPin());
    if (!mounted) return;
    if (at == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get your location. Drag the map instead.'),
        ),
      );
      return;
    }
    _map.move(at, _defaultZoom);
    _centre = at;
    await _publish(at);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _centre,
              initialZoom: _defaultZoom,
              minZoom: 4,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                // Rotation means nothing to a delivery pin, and one stray
                // two-finger twist leaves the map crooked with no way back.
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: widget.tileUrl ?? '',
                // Tile servers block unidentified clients, and OSM's policy
                // requires this specifically.
                userAgentPackageName: 'com.solecraftph.app',
                maxNativeZoom: 19,
              ),
            ],
          ),

          // The exact target, so the tip of the pin is not the only clue.
          IgnorePointer(
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: theme.primaryText.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // The pin itself. IgnorePointer so drags pass straight through to
          // the map — without it the middle of the screen, which is exactly
          // where a thumb lands, would be dead to touch.
          IgnorePointer(
            child: AnimatedSlide(
              // -0.5 lifts the glyph by half its height, putting its point on
              // the centre of the map instead of its middle. The extra lift
              // while dragging is the small "picked up" tell.
              offset: Offset(0, _dragging ? -0.62 : -0.5),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: Icon(
                Icons.location_on,
                size: 44,
                color: theme.secondary,
                shadows: const [
                  Shadow(blurRadius: 6, color: Color(0x33000000)),
                ],
              ),
            ),
          ),

          // Recentre. Bottom-right, clear of the confirm card the sheet floats
          // over the bottom edge.
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: theme.secondaryBackground,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _recentre,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.my_location,
                    size: 22,
                    color: theme.primaryText,
                  ),
                ),
              ),
            ),
          ),

          // Not decoration: attribution is a licence condition of every free
          // tile source worth using, OSM's included.
          Positioned(
            left: 6,
            bottom: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.secondaryBackground.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: Text(
                  widget.attribution ?? '',
                  style: TextStyle(fontSize: 9, color: theme.secondaryText),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
''';

  // The note above has come due: the widget body changed, so app.customWidget
  // can no longer be used on a project that already has PinMap — it is
  // create-if-missing on an exact payload match and throws on anything else.
  //
  // A fresh project still takes the ordinary create path. An existing one gets
  // the handle built directly, with the same declaration the create path would
  // have produced, and the new body pushed through updateCustomWidget. Both
  // branches read from the same three values above, so they cannot drift.
  final pinMapExists = ff.CustomCode.widgets.contains('PinMap');
  final pinMap = pinMapExists
      ? CustomWidgetHandle(
          CustomWidgetDeclaration(
            name: 'PinMap',
            parameters: pinMapParams,
            code: pinMapCode,
            description: pinMapDescription,
          ),
        )
      : app.customWidget(
          'PinMap',
          parameters: pinMapParams,
          description: pinMapDescription,
          code: pinMapCode,
        );

  if (pinMapExists) {
    app.raw(
      (project) =>
          updateCustomWidget(project, name: 'PinMap', code: pinMapCode),
    );
  }

  // OpenStreetMap's own tile servers, which are donation-funded and whose
  // usage policy rules out shipping apps pointing at them. Fine while this is
  // being tested on one phone; swap both strings for a MapTiler (or Stadia,
  // or Protomaps) template and credit before this reaches customers. That is
  // the only change needed — the widget takes the template as a parameter
  // precisely so the basemap is a one-line decision.
  //
  // ponytail: OSM public tiles, move to a keyed provider's free tier before
  // release.
  const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  const tileAttribution = '© OpenStreetMap contributors';

  // Whether the sheet was confirmed or abandoned.
  //
  // Needed because the map publishes draftPin continuously as it moves — so
  // without this, backing out of the sheet would still drop whatever happened
  // to be under the pin into the customer's address. Cancel and the Android
  // back button both leave this false, and the caller checks it before
  // touching the form.
  app.state(
    'pinConfirmed',
    bool_.withDefault(false),
    description:
        'True only when the map sheet was closed with "Use this location".',
  );

  const pinSheetName = 'PinSheet';
  const pinSheetDescription =
      'Bottom sheet: full-bleed map with a centred pin and the address it '
      'resolves to.';

  final pinSheetParams = <String, DslType>{
    'startPin': string.withDefault(''),
    // Vestigial, and deliberately kept. See the note above the editComponent
    // block below: removing it is a bigger fight than leaving it, and it costs
    // one dead `() async {}` in the generated caller.
    'onDone': action.withCallbackKind(ActionCallbackKind.onTap),
  };

  final pinSheetBody = Container(
    // Fixed pixels because Container has no percentage height on this
    // surface. 520 leaves the sheet short of full-screen on the smallest
    // phones still in use while giving the map most of the room.
    // ponytail: fixed height, revisit if it crowds a small screen.
    height: 520,
    color: Colors.primaryBackground,
    child: Column(
      children: [
        Container(
          padding: 14,
          child: Row(
            mainAxis: MainAxis.spaceBetween,
            crossAxis: CrossAxis.center,
            children: [
              Text(
                'Pin your location',
                name: 'pinSheetTitle',
                style: Styles.titleMedium,
              ),
              Container(
                name: 'pinCancel',
                padding: 8,
                child: Text(
                  'Cancel',
                  style: Styles.bodyMedium,
                  color: Colors.secondaryText,
                ),
                onTap: [
                  UpdateAppState.set(ff.AppState.pinConfirmed, false),
                  const NavigateBack(),
                  const ParamAction('onDone'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          pinMap(
            name: 'pinSheetMap',
            startPin: Param('startPin'),
            tileUrl: tileUrl,
            attribution: tileAttribution,
          ),
        ),
        Container(
          padding: 16,
          color: Colors.secondaryBackground,
          child: Column(
            crossAxis: CrossAxis.start,
            spacing: 8,
            children: [
              Text(
                'Drag the map to move the pin',
                name: 'pinSheetHint',
                style: Styles.bodySmall,
                color: Colors.secondaryText,
              ),
              // One of these two is always showing. The placeholder is not
              // decoration: the address field is deliberately blanked while
              // a lookup is in flight, and an empty gap there reads as a
              // failure rather than as work in progress.
              Text(
                'Finding address...',
                name: 'pinSheetSearching',
                style: Styles.titleSmall,
                color: Colors.secondaryText,
                visible: Equals(AppState(ff.AppState.draftPinText), ''),
              ),
              Text(
                AppState(ff.AppState.draftPinText),
                name: 'pinSheetAddress',
                style: Styles.titleSmall,
                maxLines: 2,
                visible: Not(Equals(AppState(ff.AppState.draftPinText), '')),
              ),
              Text(
                AppState(ff.AppState.draftPin),
                name: 'pinSheetCoords',
                style: Styles.bodySmall,
                color: Colors.secondaryText,
              ),
              Button(
                'Use this location',
                name: 'pinConfirm',
                width: double.infinity,
                height: 52,
                borderRadius: 12,
                onTap: [
                  UpdateAppState.set(ff.AppState.pinConfirmed, true),
                  const NavigateBack(),
                  const ParamAction('onDone'),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // app.component is strict-create on purpose — an upsert would silently
  // overwrite a component body edited in the FlutterFlow IDE — so a second run
  // of this file dies on "a page or component named PinSheet already exists".
  // Once it is in the project, hand ShowBottomSheet a handle built from the
  // same declaration instead: the compiler only reads the name and the param
  // types off it, and looks the real component up in the project by name.
  //
  // The consequence to know about: after the first run, edits to
  // `pinSheetBody` above stop reaching the project. Changing the sheet's
  // appearance later means `app.editComponent(...)`, not editing that tree —
  // which is exactly what the block after this one does.
  final pinSheet =
      ff.Components.all.any((c) => c.name == pinSheetName)
          ? ComponentHandle(
            ComponentDeclaration(
              name: pinSheetName,
              description: pinSheetDescription,
              params: pinSheetParams,
              body: pinSheetBody,
            ),
          )
          : app.component(
                pinSheetName,
                description: pinSheetDescription,
                params: pinSheetParams,
                body: pinSheetBody,
              )
              as ComponentHandle;

  // Closing the sheet, take three.
  //
  // 1. DismissDialog inside the component: rejected outright — "Dismiss Dialog
  //    action is used, but there is no action to open a custom dialog". A
  //    bottom sheet does not count as one.
  // 2. Routed out to the caller as an `onDone` callback param, so the dismiss
  //    sat beside the ShowBottomSheet that opened it. That validated, pushed,
  //    and generated `onDone: () async {}` — an empty body. The chain does not
  //    survive into a component parameter placed by a bottom sheet, with or
  //    without a callback kind on the parameter. Two buttons that did nothing,
  //    and nothing anywhere said so.
  // 3. This: pop the route from inside the sheet. A modal sheet *is* a route,
  //    Navigate Back pops the top one, and there is no validator rule about
  //    it. Fewest moving parts of the three.
  //
  // Applied through editComponent because the declared body above stopped
  // reaching the project the moment the component existed.
  // `onDone` stays declared, passed, and called, even though its body is empty
  // and the pop no longer goes through it. Deleting it costs two more fights,
  // both of which were had:
  //
  //  - The wiring review rejects a component parameter the widget tree does
  //    not reference, so the param has to go at the same time as the last
  //    ParamAction that mentions it.
  //  - ensureActions skips a chain it considers semantically equal, and that
  //    comparison does not look at component parameter values. Dropping
  //    `onDone` from the ShowBottomSheet call is invisible to it, so the old
  //    chain stays put and then fails validation for passing a parameter that
  //    no longer exists. Removing it needs a chain that differs some *other*
  //    way, in the same run, at both call sites.
  //
  // One dead `() async {}` per call site is the cheaper end of that trade.
  if (ff.Components.all.any((c) => c.name == pinSheetName)) {
    app.editComponent(ff.Components.pinSheet, (sheet) {
      sheet.ensureActions(
        ff.Components.pinSheet.widgets.byKey('Container_5msrfwjs').single,
        triggerType: FFActionTriggerType.ON_TAP,
        actions: [
          UpdateAppState.set(ff.AppState.pinConfirmed, false),
          const NavigateBack(),
          const ParamAction('onDone'),
        ],
      );
      sheet.ensureActions(
        ff.Components.pinSheet.widgets.byKey('Button_6vpby2te').single,
        triggerType: FFActionTriggerType.ON_TAP,
        actions: [
          UpdateAppState.set(ff.AppState.pinConfirmed, true),
          const NavigateBack(),
          const ParamAction('onDone'),
        ],
      );
    });
  }

  // `Equals(State('saved'), [])` is not expressible — a Dart list literal is
  // not a DSL expression — so the empty state asks a function instead.
  final hasNoAddresses = app.customFunction(
    'hasNoAddresses',
    args: {'rows': listOf(addressRow)},
    returns: bool_,
    code: r'''
return (rows ?? <AddressRowStruct>[]).isEmpty;
''',
    description: 'True when the shopper has saved no addresses yet.',
  );
  app.apiGroup(
    'Api',
    baseUrl: 'https://snow-jellyfish-553645.hostingersite.com/api',
    headers: const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    endpoints: [
      cartGet,
      cartReplace,
      cartMerge,
      login,
      register,
      createOrder,
      getOrder,
      getOrderDetail,
      getProfile,
      updateProfile,
      changePassword,
      getNotifications,
      markNotificationsRead,
      getWishlist,
      wishlistHas,
      toggleWishlist,
      getProduct,
      getReviews,
      createReview,
      getInfoPages,
      getInfoPage,
      sendContact,
      authSession,
      getSettings,
      getProducts,
      myOrdersList,
      registerDevice,
      getTaxonomy,
      getProductsFiltered,
      getAddresses,
      saveAddress,
      deleteAddress,
      defaultAddress,
      createOrderPinned,
    ],
  );

  // ---------------------------------------------------------------------------
  // 3. Custom functions
  // ---------------------------------------------------------------------------
  // Serializes the bag down to what the server actually accepts from a client:
  // which product, which size, how many. Name and price are the server's to
  // decide, so they are not sent.
  final cartLines = app.customFunction(
    'cartLines',
    args: {'items': listOf(ff.Structs.bagItem)},
    returns: json,
    code: r'''
return (items ?? <BagItemStruct>[])
    .map((line) => {
          'product_id': line.id ?? 0,
          'size': line.size ?? '',
          'qty': (line.qty ?? 0).toInt(),
        })
    .toList();
''',
    description:
        'Bag as the cart API wants it: product_id, size, qty per line.',
  );

  // api/orders.php now answers with the PayMongo Hosted Checkout URL for a
  // GCASH/CARD order (empty string for COD), so OrderCreated needs somewhere to
  // put it. Guarded rather than ensured: addDataStructField throws on a rerun.
  app.raw((project) {
    final existing = findDataStructField(
      project,
      structName: 'OrderCreated',
      fieldName: 'checkout_url',
    );
    if (existing == null) {
      addDataStructField(
        project,
        structName: 'OrderCreated',
        fieldName: 'checkout_url',
        type: FFDataTypeV2(scalarType: FFBaseDataType.String),
        description: 'PayMongo Hosted Checkout URL. Empty for COD orders.',
      );
    }
  });

  // `orderItems` keyed purely by product id, which silently collapsed the same
  // shoe in two sizes into one line — last write won. Key on id + size instead,
  // and pass the size through so it lands in `order_items.size`.
  app.raw((project) {
    updateCustomFunction(
      project,
      name: 'orderItems',
      description:
          'Builds the orders.php items object, one entry per product + size.',
      code: r'''
final map = <String, dynamic>{};
for (final line in (items ?? <BagItemStruct>[])) {
  final id = line.id ?? 0;
  final size = line.size ?? '';
  map['$id|$size'] = {
    'product_id': id,
    'name': line.name ?? '',
    'size': size,
    'price': (line.price ?? 0).toDouble(),
    'qty': (line.qty ?? 0).toInt(),
  };
}
return map;
''',
    );
  });

  // ---------------------------------------------------------------------------
  // 3b. The four criticals from APP-REVIEW.md
  // ---------------------------------------------------------------------------
  // api/products.php now sends `available_sizes` — the US sizes with stock
  // left, or every offered size for a shoe not yet counted per size. Guarded
  // rather than ensured: addDataStructField throws on a rerun.
  app.raw((project) {
    final existing = findDataStructField(
      project,
      structName: 'Shoe',
      fieldName: 'available_sizes',
    );
    if (existing == null) {
      addDataStructField(
        project,
        structName: 'Shoe',
        fieldName: 'available_sizes',
        type: FFDataTypeV2(scalarType: FFBaseDataType.String),
        isList: true,
        description:
            'US sizes still in stock. Empty only when the shoe is sold out.',
      );
    }
  });

  // Whether one size tile can still be tapped. An empty list means the shoe
  // predates per-size stock — every size stays tappable and order_create keeps
  // the last word, which is how the app behaved before sizes were counted.
  final sizeSellable = app.customFunction(
    'sizeSellable',
    args: {'availableSizes': listOf(string), 'size': string},
    returns: bool_,
    code: r'''
final sizes = availableSizes ?? const <String>[];
if (sizes.isEmpty) return true;
return sizes.contains(size ?? '');
''',
    description: 'Whether this US size is still buyable.',
  );

  // Empty when the shoe, size and quantity under the cursor may go in the bag,
  // otherwise the reason they may not — one call both decides and explains, so
  // the refusal always carries a message the shopper can act on.
  final bagBlocker = app.customFunction(
    'bagBlocker',
    args: {
      'availableSizes': listOf(string),
      'size': string,
      'stock': int_,
      'qty': int_,
    },
    returns: string,
    code: r'''
final chosen = size ?? '';
if (chosen.isEmpty) return 'Choose a size first.';
final sizes = availableSizes ?? const <String>[];
if (sizes.isNotEmpty && !sizes.contains(chosen)) {
  return 'US $chosen is sold out.';
}
final left = stock ?? 0;
if (left < 1) return 'This shoe is out of stock.';
if ((qty ?? 1) > left) {
  return left == 1 ? 'Only 1 left in stock.' : 'Only $left left in stock.';
}
return '';
''',
    description: 'Why this shoe cannot go in the bag; empty when it can.',
  );

  /// onFailure for an authenticated call: asks the server whether the token is
  /// still good, and acts on the answer. Alive means this was a transient
  /// failure and [otherwise] stands; dead signs the customer out and says so.
  /// A probe that cannot be reached at all is a flat connection, not an
  /// expired session, so it falls back to [otherwise] and nobody gets signed
  /// out over a dropped signal. Without any of this the screen just renders
  /// empty, which reads as "you have nothing here".
  List<DslAction> authFailure(String outputName, String otherwise) => [
    ApiCall(
      authSession,
      outputAs: '${outputName}Probe',
      params: {'token': AppState(ff.AppState.authToken)},
      onSuccess:
          (res) => [
            If(
              res['valid'],
              then: [Snackbar(otherwise)],
              orElse: [
                UpdateAppState.set(ff.AppState.authToken, ''),
                UpdateAppState.set(ff.AppState.signedIn, false),
                Snackbar('Your session expired. Please sign in again.'),
                Navigate.to(ff.Pages.signIn),
              ],
            ),
          ],
      onFailure: [Snackbar(otherwise)],
    ),
  ];

  // The account-area loads, lifted out of their ensurePage blocks so a
  // pull-to-refresh can run the same chain the page load runs. [tag] keeps the
  // two copies' output variables apart — FlutterFlow rejects a page where two
  // widgets produce the same output name.
  List<DslAction> loadNotifications(String tag) => [
    ApiCall(
      getNotifications,
      outputAs: 'notificationsLoad$tag',
      params: {'token': AppState(ff.AppState.authToken)},
      onSuccess: (res) => [SetState(ff.Pages.notifications.state.feed, res)],
      onFailure: authFailure(
        'notificationsLoad$tag',
        'Could not load your notifications.',
      ),
    ),
  ];

  List<DslAction> loadWishlist(String tag) => [
    ApiCall(
      getWishlist,
      outputAs: 'wishlistLoad$tag',
      params: {'token': AppState(ff.AppState.authToken)},
      onSuccess: (res) => [SetState(ff.Pages.wishlist.state.saved, res)],
      onFailure: authFailure(
        'wishlistLoad$tag',
        'Could not load your wishlist.',
      ),
    ),
  ];

  List<DslAction> loadReviews(String tag) => [
    ApiCall(
      getReviews,
      outputAs: 'reviewsLoad$tag',
      params: {
        'token': AppState(ff.AppState.authToken),
        'product_id': PageParam('productId'),
      },
      onSuccess: (res) => [SetState(ff.Pages.reviews.state.feed, res)],
      onFailure: [Snackbar('Could not load reviews.')],
    ),
  ];

  // ---------------------------------------------------------------------------
  // 4. The two sync halves, reused by every wiring point below
  // ---------------------------------------------------------------------------
  List<DslAction> pushBag(String outputName) => [
    If(
      AppState(ff.AppState.signedIn),
      then: [
        ApiCall(
          cartReplace,
          outputAs: outputName,
          params: {
            'token': AppState(ff.AppState.authToken),
            'items': CustomFunction(
              cartLines,
              args: {'items': AppState(ff.AppState.bag)},
            ),
          },
          // The server answer is authoritative — it has clamped to stock
          // and dropped anything no longer for sale.
          onSuccess:
              (res) => [UpdateAppState.set(ff.AppState.bag, res['items'])],
          onFailure: [
            Snackbar('Could not sync your bag. It is saved on this device.'),
          ],
        ),
      ],
    ),
  ];

  List<DslAction> pullBag(String outputName) => [
    If(
      AppState(ff.AppState.signedIn),
      then: [
        ApiCall(
          cartGet,
          outputAs: outputName,
          params: {'token': AppState(ff.AppState.authToken)},
          onSuccess:
              (res) => [UpdateAppState.set(ff.AppState.bag, res['items'])],
          onFailure: authFailure(outputName, 'Could not load your bag.'),
        ),
      ],
    ),
  ];

  // ---------------------------------------------------------------------------
  // 5. ShoeDetails — both buttons that add to the bag
  // ---------------------------------------------------------------------------
  // ensureActions replaces the whole trigger chain, so the original actions are
  // restated here ahead of the sync step.
  final addToBagItem = Struct(ff.Structs.bagItem, {
    'id': State(ff.Pages.shoeDetails.state.shoe)['id'],
    'name': State(ff.Pages.shoeDetails.state.shoe)['name'],
    'size': State(ff.Pages.shoeDetails.state.selectedSize),
    'qty': State(ff.Pages.shoeDetails.state.qty),
    'price': CustomFunction(
      CustomFunctionHandle(
        name: 'toNum',
        args: {'value': string},
        returnType: double_,
      ),
      args: {
        'value': CustomFunction(
          CustomFunctionHandle(
            name: 'activePrice',
            args: {'price': string, 'salePrice': string},
            returnType: string,
          ),
          args: {
            'price': State(ff.Pages.shoeDetails.state.shoe)['price'],
            'salePrice': State(ff.Pages.shoeDetails.state.shoe)['sale_price'],
          },
        ),
      },
    ),
    'image': State(ff.Pages.shoeDetails.state.shoe)['image'],
  });

  // Nothing stopped a shopper adding a size the shoe has none of, or more
  // pairs than exist — order_create refused it, but only after the address and
  // payment method had been filled in. Decide here instead, and say why.
  final bagRefusal = CustomFunction(
    bagBlocker,
    args: {
      'availableSizes':
          State(ff.Pages.shoeDetails.state.shoe)['available_sizes'],
      'size': State(ff.Pages.shoeDetails.state.selectedSize),
      'stock': State(ff.Pages.shoeDetails.state.shoe)['stock'],
      'qty': State(ff.Pages.shoeDetails.state.qty),
    },
  );

  /// [whenOk] only runs when the shoe, size and quantity are actually buyable.
  List<DslAction> guardBag(List<DslAction> whenOk) => [
    If(Equals(bagRefusal, ''), then: whenOk, orElse: [Snackbar(bagRefusal)]),
  ];

  app.editPage(ff.Pages.shoeDetails, (page) {
    page.ensureActions(
      ff.Pages.shoeDetails.widgets.byKey('Button_jfnhj8yy').single,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: guardBag([
        UpdateAppState.addToList(ff.AppState.bag, addToBagItem),
        Snackbar('Added to bag'),
        ...pushBag('addToBagSyncRes'),
      ]),
    );

    page.ensureActions(
      ff.Pages.shoeDetails.widgets.byKey('Button_zce571f8').single,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: guardBag([
        UpdateAppState.addToList(ff.AppState.bag, addToBagItem),
        // Navigation goes BEFORE the sync: everything after an ApiCall compiles
        // into its success branch, so a failed (or skipped, when signed out)
        // sync would otherwise strand the shopper on this page.
        Navigate.to(ff.Pages.checkout),
        ...pushBag('buyNowSyncRes'),
      ]),
    );

    // The six size tiles. Each one set selectedSize unconditionally, so the
    // picker happily offered a US 12 the shop has none of; available_sizes
    // decides now, and a sold-out tap says so rather than doing nothing.
    for (final tile
        in const <String, String>{
          'Container_dnejwlbx': '7',
          'Container_nutazx4c': '8',
          'Container_zr4v91kl': '9',
          'Container_p5rm8umn': '10',
          'Container_582gr6n9': '11',
          'Container_xoentfqj': '12',
        }.entries) {
      page.ensureActions(
        ff.Pages.shoeDetails.widgets.byKey(tile.key).single,
        triggerType: FFActionTriggerType.ON_TAP,
        actions: [
          If(
            CustomFunction(
              sizeSellable,
              args: {
                'availableSizes':
                    State(ff.Pages.shoeDetails.state.shoe)['available_sizes'],
                'size': tile.value,
              },
            ),
            then: [
              SetState(ff.Pages.shoeDetails.state.selectedSize, tile.value),
            ],
            orElse: [Snackbar('US ${tile.value} is sold out.')],
          ),
        ],
      );
    }
  });

  // Quantity arithmetic has to live in custom code — the DSL has no
  // expression for `qty + 1`. Clamped at 1 (dropping to 0 is what Remove is
  // for) and at 99; the server clamps to real stock on the way in anyway.
  final bumpQty = app.customFunction(
    'bumpQty',
    args: {'qty': int_, 'delta': int_},
    returns: int_,
    code: r'''
final next = (qty ?? 1) + (delta ?? 0);
if (next < 1) return 1;
if (next > 99) return 99;
return next;
''',
    description: 'Steps a bag line quantity by delta, clamped to 1..99.',
  );

  /// Rewrites the bag line under the cursor with [newQty], then syncs.
  List<DslAction> stepQty(int delta, String outputName) => [
    UpdateAppState.updateItemAtIndex(
      ff.AppState.bag,
      ItemRef().index,
      Struct(ff.Structs.bagItem, {
        'id': ItemRef()['id'],
        'name': ItemRef()['name'],
        'size': ItemRef()['size'],
        'image': ItemRef()['image'],
        'price': ItemRef()['price'],
        'qty': CustomFunction(
          bumpQty,
          args: {'qty': ItemRef()['qty'], 'delta': delta},
        ),
      }),
    ),
    ...pushBag('stepQtySyncRes$outputName'),
  ];

  // ---------------------------------------------------------------------------
  // 6. Bag — remove one line, clear everything, and pull on open
  // ---------------------------------------------------------------------------
  app.editPage(ff.Pages.bag, (page) {
    page.ensureActions(
      ff.Pages.bag.widgets.byKey('IconButton_vtj0lvjt').single,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [
        UpdateAppState.removeAtIndex(ff.AppState.bag, ItemRef().index),
        ...pushBag('removeLineSyncRes'),
      ],
    );

    page.ensureActions(
      ff.Pages.bag.widgets.byKey('Button_yymk5f27').single,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [
        ClearAppState(ff.AppState.bag),
        Snackbar('Bag cleared'),
        ...pushBag('clearBagSyncRes'),
      ],
    );

    // The bag could remove a line but never change 2 to 1 — the website can.
    // The bare quantity number becomes a −/number/+ stepper in its place.
    //
    // Inserted bare, then bound below: a widget handed to ensureReplaced is
    // compiled before it is grafted into the tree, so an ItemRef() inside it
    // has no ListView builder to resolve against. Binding afterwards resolves
    // against the node in its final position, where the builder scope exists.
    // Guarded: once the swap has run, the original Text no longer exists and a
    // bare .single would throw on every later run of this script.
    if (ff.Pages.bag.widgets.byKey('Text_j1x5374q').matches.isNotEmpty)
      page.ensureReplaced(
        ff.Pages.bag.widgets.byKey('Text_j1x5374q').single,
        Row(
          name: 'qtyStepper',
          mainAxis: MainAxis.end,
          crossAxis: CrossAxis.center,
          spacing: 2,
          children: [
            IconButton(
              'remove',
              name: 'qtyDown',
              size: 28,
              color: Colors.secondaryText,
            ),
            Text('0', name: 'qtyValue', style: Styles.bodyMedium),
            IconButton(
              'add',
              name: 'qtyUp',
              size: 28,
              color: Colors.primaryText,
            ),
          ],
        ),
      );

    page.bindText(
      ff.Pages.bag.widgets.byKey('Text_3czhhb78').single,
      ItemRef()['qty'],
    );
    page.ensureActions(
      ff.Pages.bag.widgets.byKey('IconButton_68d3z5ax').single,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: stepQty(-1, 'Down'),
    );
    page.ensureActions(
      ff.Pages.bag.widgets.byKey('IconButton_vi892kbi').single,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: stepQty(1, 'Up'),
    );
  });

  // Opening the Bag is the moment to find out what the account's cart really
  // holds — this is how something added on the website shows up on the phone.
  app.editPageOnLoad(ff.Pages.bag, pullBag('bagLoadSyncRes'));

  app.editPageOnLoad(ff.Pages.confirmed, [
    ApiCall(
      getOrder,
      outputAs: 'confirmLoad',
      params: {
        'id': PageParam('orderId'),
        'token': AppState(ff.AppState.authToken),
      },
      onSuccess: (res) => [SetState(ff.Pages.confirmed.state.order, res)],
    ),
  ]);

  // Every TextField commits to page state through a 2000 ms debounce, so a
  // shopper who types and taps straight away sends the PREVIOUS keystroke's
  // value — the request fails, nothing visible happens, and tapping again a
  // second later works. That is the "have to double-tap" behaviour. Reading the
  // field's live text at tap time removes the race entirely.
  // ---------------------------------------------------------------------------
  // 7. Sign-in and register — fold a signed-out bag into the account
  // ---------------------------------------------------------------------------
  // Sign-in is the ONLY moment a merge is correct. Everywhere else the server
  // wins, so that removing something on the website actually removes it on the
  // phone; here the local bag was never on the server, so it has to be added.
  List<DslAction> mergeBag(String outputName) => [
    ApiCall(
      cartMerge,
      outputAs: outputName,
      params: {
        'token': AppState(ff.AppState.authToken),
        'items': CustomFunction(
          cartLines,
          args: {'items': AppState(ff.AppState.bag)},
        ),
      },
      onSuccess: (res) => [UpdateAppState.set(ff.AppState.bag, res['items'])],
    ),
  ];

  app.editPage(ff.Pages.signIn, (page) {
    page.ensureActions(
      ff.Pages.signIn.widgets.byKey('Button_sv4216kt').single,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [
        SetState(ff.Pages.signIn.state.busy, true),
        ApiCall(
          login,
          outputAs: 'loginRes',
          params: {
            'login': WidgetState('siLogin', WidgetStateProperty.text),
            'password': WidgetState('siPassword', WidgetStateProperty.text),
          },
          onSuccess:
              (res) => [
                SetState(ff.Pages.signIn.state.busy, false),
                UpdateAppState.set(ff.AppState.authToken, res['token']),
                UpdateAppState.set(ff.AppState.signedIn, true),
                UpdateAppState.set(ff.AppState.userId, res['user']['id']),
                UpdateAppState.set(
                  ff.AppState.username,
                  res['user']['username'],
                ),
                UpdateAppState.set(ff.AppState.userEmail, res['user']['email']),
                UpdateAppState.set(
                  ff.AppState.userFullName,
                  res['user']['full_name'],
                ),
                UpdateAppState.set(ff.AppState.userPhone, res['user']['phone']),
                UpdateAppState.set(
                  ff.AppState.userAddress,
                  res['user']['address'],
                ),
                UpdateAppState.set(ff.AppState.userRole, res['user']['role']),
                UpdateAppState.set(
                  ff.AppState.isAdmin,
                  res['user']['is_admin'],
                ),
                // Sign the user in and move them along first — the merge must never
                // be able to hold up a successful login (see the note on Buy Now).
                Snackbar('Signed in'),
                Navigate.to(ff.Pages.shop),
                ...mergeBag('signInMergeRes'),
              ],
          onFailure: [
            SetState(ff.Pages.signIn.state.busy, false),
            Snackbar('Incorrect username/email or password.'),
          ],
        ),
      ],
    );
  });

  final orderDetailPage = app.ensurePage(
    'OrderDetail',
    route: '/order-detail',
    description:
        'One order: what was bought, what was paid, where it has got to.',
    params: {'orderId': int_.withDefault(0)},
    state: {'order': orderFull, 'loading': bool_.withDefault(true)},
    onLoad: [
      ApiCall(
        getOrderDetail,
        outputAs: 'orderDetailLoad',
        params: {
          'id': PageParam('orderId'),
          'token': AppState(ff.AppState.authToken),
        },
        onSuccess:
            (res) => [
              SetState(ff.Pages.orderDetail.state.order, res),
              SetState(ff.Pages.orderDetail.state.loading, false),
            ],
        onFailure: [
          SetState(ff.Pages.orderDetail.state.loading, false),
          Snackbar('Could not load that order.'),
        ],
      ),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Order'),
      body: Column(
        scrollable: true,
        crossAxis: CrossAxis.start,
        spacing: 20,
        padding: 16,
        children: [
          ProgressBar.circular(
            size: 28,
            name: 'orderLoading',
            visible: State(ff.Pages.orderDetail.state.loading),
          ),

          // Summary card
          Container(
            padding: 16,
            borderRadius: 12,
            color: Colors.secondaryBackground,
            child: Column(
              crossAxis: CrossAxis.start,
              spacing: 10,
              children: [
                Text(
                  State(ff.Pages.orderDetail.state.order)['status'],
                  style: Styles.titleMedium,
                ),
                _detailRow(
                  'Placed',
                  State(ff.Pages.orderDetail.state.order)['created_at'],
                ),
                _detailRow(
                  'Payment',
                  State(ff.Pages.orderDetail.state.order)['payment_method'],
                ),
                _detailRow(
                  'Payment status',
                  State(ff.Pages.orderDetail.state.order)['payment_status'],
                ),
                _detailRow(
                  'Total',
                  CustomFunction(
                    CustomFunctionHandle(
                      name: 'peso',
                      args: {'value': string},
                      returnType: string,
                    ),
                    args: {
                      'value':
                          State(
                            ff.Pages.orderDetail.state.order,
                          )['total_amount'],
                    },
                  ),
                ),
                _detailRow(
                  'Tracking',
                  State(ff.Pages.orderDetail.state.order)['tracking_number'],
                  visibleWhen: Not(
                    Equals(
                      State(
                        ff.Pages.orderDetail.state.order,
                      )['tracking_number'],
                      '',
                    ),
                  ),
                ),
              ],
            ),
          ),

          Text('Items', style: Styles.titleSmall),
          ListView(
            source: State(ff.Pages.orderDetail.state.order)['items'],
            shrinkWrap: true,
            scrollPhysics: ScrollPhysics.never,
            spacing: 10,
            itemBuilder:
                (item) => Row(
                  mainAxis: MainAxis.spaceBetween,
                  crossAxis: CrossAxis.start,
                  spacing: 12,
                  children: [
                    Column(
                      crossAxis: CrossAxis.start,
                      spacing: 2,
                      children: [
                        Text(
                          ItemRef()['product_name'],
                          style: Styles.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          ItemRef()['size'],
                          style: Styles.bodySmall,
                          color: Colors.secondaryText,
                        ),
                      ],
                    ),
                    Text(
                      CustomFunction(
                        CustomFunctionHandle(
                          name: 'peso',
                          args: {'value': string},
                          returnType: string,
                        ),
                        args: {'value': ItemRef()['subtotal']},
                      ),
                      style: Styles.bodyMedium,
                    ),
                  ],
                ),
          ),

          Text('Tracking history', style: Styles.titleSmall),
          ListView(
            source: State(ff.Pages.orderDetail.state.order)['status_history'],
            shrinkWrap: true,
            scrollPhysics: ScrollPhysics.never,
            spacing: 12,
            itemBuilder:
                (item) => Column(
                  crossAxis: CrossAxis.start,
                  spacing: 2,
                  children: [
                    Text(ItemRef()['status'], style: Styles.bodyMedium),
                    Text(
                      ItemRef()['created_at'],
                      style: Styles.bodySmall,
                      color: Colors.secondaryText,
                    ),
                    Text(
                      ItemRef()['note'],
                      style: Styles.bodySmall,
                      color: Colors.secondaryText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
          ),

          Text('Delivering to', style: Styles.titleSmall),
          Column(
            crossAxis: CrossAxis.start,
            spacing: 2,
            children: [
              Text(
                State(ff.Pages.orderDetail.state.order)['customer_name'],
                style: Styles.bodyMedium,
              ),
              Text(
                State(ff.Pages.orderDetail.state.order)['customer_phone'],
                style: Styles.bodySmall,
                color: Colors.secondaryText,
              ),
              Text(
                State(ff.Pages.orderDetail.state.order)['customer_address'],
                style: Styles.bodySmall,
                color: Colors.secondaryText,
                maxLines: 4,
              ),
            ],
          ),
        ],
      ),
    ),
  );

  // Tapping a row in MyOrders finally opens something.
  app.editPage(ff.Pages.myOrders, (page) {
    page.ensureActions(
      ff.Pages.myOrders.widgets.byKey('Container_x3gjkj3t').single,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [
        Navigate.to(orderDetailPage, params: {'orderId': ItemRef()['id']}),
      ],
    );
  });

  // ---------------------------------------------------------------------------
  // 7c. Profile — edit details and change password
  // ---------------------------------------------------------------------------
  // The form starts empty and blank fields mean "leave unchanged" server-side,
  // because the DSL's TextField takes no initial value — there is no way to
  // pre-fill it from the loaded profile. The current details are shown above the
  // form instead, so nothing is hidden from the shopper.
  final profilePage = app.ensurePage(
    'Profile',
    route: '/profile',
    description:
        'Name, phone and delivery address, plus changing the password.',
    state: {'me': profileStruct, 'saving': bool_.withDefault(false)},
    onLoad: [
      ApiCall(
        getProfile,
        outputAs: 'profileLoad',
        params: {'token': AppState(ff.AppState.authToken)},
        onSuccess: (res) => [SetState(ff.Pages.profile.state.me, res)],
        onFailure: authFailure('profileLoad', 'Could not load your profile.'),
      ),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Profile'),
      body: Column(
        scrollable: true,
        crossAxis: CrossAxis.start,
        spacing: 20,
        padding: 16,
        children: [
          Container(
            padding: 16,
            borderRadius: 12,
            color: Colors.secondaryBackground,
            child: Column(
              crossAxis: CrossAxis.start,
              spacing: 10,
              children: [
                Text(
                  State(ff.Pages.profile.state.me)['username'],
                  style: Styles.titleMedium,
                ),
                _detailRow('Email', State(ff.Pages.profile.state.me)['email']),
                _detailRow(
                  'Name',
                  State(ff.Pages.profile.state.me)['full_name'],
                ),
                _detailRow('Phone', State(ff.Pages.profile.state.me)['phone']),
                _detailRow(
                  'Address',
                  State(ff.Pages.profile.state.me)['address'],
                ),
              ],
            ),
          ),

          Text('Update your details', style: Styles.titleSmall),
          Text(
            'Leave a box empty to keep what you have now.',
            style: Styles.bodySmall,
            color: Colors.secondaryText,
          ),
          TextField(label: 'Full name', name: 'pfName'),
          TextField(
            label: 'Mobile number',
            name: 'pfPhone',
            keyboard: Keyboard.number,
          ),
          TextField(label: 'Delivery address', name: 'pfAddress', maxLines: 3),
          Button(
            'Save changes',
            name: 'pfSave',
            width: double.infinity,
            height: 52,
            borderRadius: 12,
            onTap: [
              SetState(ff.Pages.profile.state.saving, true),
              ApiCall(
                updateProfile,
                outputAs: 'profileSaveRes',
                params: {
                  'token': AppState(ff.AppState.authToken),
                  'full_name': WidgetState('pfName', WidgetStateProperty.text),
                  'phone': WidgetState('pfPhone', WidgetStateProperty.text),
                  'address': WidgetState('pfAddress', WidgetStateProperty.text),
                },
                onSuccess:
                    (res) => [
                      SetState(ff.Pages.profile.state.saving, false),
                      SetState(ff.Pages.profile.state.me, res['profile']),
                      // Keep the rest of the app in step — Checkout and Account read
                      // these, and a stale address there would be worse than none.
                      UpdateAppState.set(
                        ff.AppState.userFullName,
                        res['profile']['full_name'],
                      ),
                      UpdateAppState.set(
                        ff.AppState.userPhone,
                        res['profile']['phone'],
                      ),
                      UpdateAppState.set(
                        ff.AppState.userAddress,
                        res['profile']['address'],
                      ),
                      Snackbar('Your profile has been updated.'),
                    ],
                onFailure: [
                  SetState(ff.Pages.profile.state.saving, false),
                  Snackbar('Could not save your details. Please try again.'),
                ],
              ),
            ],
          ),

          Text('Change password', style: Styles.titleSmall),
          TextField(
            label: 'Current password',
            name: 'pfCurrent',
            obscureText: true,
          ),
          TextField(
            label: 'New password',
            name: 'pfNew',
            obscureText: true,
            hint: 'At least 8 characters',
          ),
          Button(
            'Change password',
            name: 'pfChangePassword',
            variant: ButtonVariant.outlined,
            width: double.infinity,
            height: 52,
            borderRadius: 12,
            onTap: [
              ApiCall(
                changePassword,
                outputAs: 'passwordRes',
                params: {
                  'token': AppState(ff.AppState.authToken),
                  'current_password': WidgetState(
                    'pfCurrent',
                    WidgetStateProperty.text,
                  ),
                  'new_password': WidgetState(
                    'pfNew',
                    WidgetStateProperty.text,
                  ),
                },
                // Changing the password revokes every token server-side, so the
                // session in hand is already dead. Sign out rather than let the
                // app keep making calls that will all 401.
                onSuccess:
                    (res) => [
                      UpdateAppState.set(ff.AppState.authToken, ''),
                      UpdateAppState.set(ff.AppState.signedIn, false),
                      Snackbar('Password changed. Please sign in again.'),
                      Navigate.to(ff.Pages.signIn),
                    ],
                onFailure: [
                  Snackbar(
                    'Could not change your password. Check the current one and try again.',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );

  // Account's list had My orders / My bag / the website but no way to reach the
  // account itself — the website's account sub-nav has had Profile all along.
  // ensureInsertedBefore is NOT idempotent — a second run inserts a second copy.
  // Guarded on the tile's name so re-running this script leaves one of each.
  app.editPage(ff.Pages.account, (page) {
    // A duplicate Profile tile from the run that discovered the above.
    if (ff.Pages.account.widgets
        .byKey('ListTile_vjceoeq6')
        .matches
        .isNotEmpty) {
      page.ensureRemoved(
        ff.Pages.account.widgets.byKey('ListTile_vjceoeq6').single,
      );
    }
    if (!ff.Pages.account.widgets.all.any(
      (w) => w.name == 'accountProfileTile',
    )) {
      page.ensureInsertedBefore(
        ff.Pages.account.widgets.byKey('ListTile_81kcu172').single,
        ListTile(
          title: 'Profile',
          leadingIcon: 'person_outline',
          name: 'accountProfileTile',
          onTap: [Navigate.to(profilePage)],
        ),
      );
    }
  });

  // ---------------------------------------------------------------------------
  // 7d. Notifications — order updates that were already being written
  // ---------------------------------------------------------------------------
  // Unread rows carry a blaze dot; tapping "Mark all read" clears them and the
  // response is written straight back, so the list and the count can't disagree.
  final notificationsPage = app.ensurePage(
    'Notifications',
    route: '/notifications',
    description: 'Order updates and announcements for the signed-in shopper.',
    state: {'feed': notificationList},
    onLoad: loadNotifications(''),
    body: Scaffold(
      appBar: AppBar(title: 'Notifications'),
      body: Column(
        scrollable: true,
        crossAxis: CrossAxis.start,
        spacing: 12,
        padding: 16,
        children: [
          Row(
            mainAxis: MainAxis.spaceBetween,
            crossAxis: CrossAxis.center,
            spacing: 12,
            children: [
              Text(
                State(ff.Pages.notifications.state.feed)['unread'],
                name: 'unreadCount',
                style: Styles.titleMedium,
              ),
              Button(
                'Mark all read',
                name: 'markAllRead',
                variant: ButtonVariant.outlined,
                height: 52,
                borderRadius: 12,
                onTap: [
                  ApiCall(
                    markNotificationsRead,
                    outputAs: 'markReadRes',
                    params: {'token': AppState(ff.AppState.authToken)},
                    onSuccess:
                        (res) => [
                          SetState(ff.Pages.notifications.state.feed, res),
                        ],
                    onFailure: [
                      Snackbar('Could not update your notifications.'),
                    ],
                  ),
                ],
              ),
            ],
          ),

          Text(
            'Nothing here yet. Order updates will show up as they happen.',
            name: 'notificationsEmpty',
            style: Styles.bodyMedium,
            color: Colors.secondaryText,
            visible: Equals(
              State(ff.Pages.notifications.state.feed)['count'],
              0,
            ),
          ),

          ListView(
            source: State(ff.Pages.notifications.state.feed)['items'],
            shrinkWrap: true,
            scrollPhysics: ScrollPhysics.never,
            spacing: 10,
            itemBuilder:
                (item) => Container(
                  padding: 14,
                  borderRadius: 12,
                  color: Colors.secondaryBackground,
                  child: Row(
                    crossAxis: CrossAxis.start,
                    spacing: 10,
                    children: [
                      // The unread marker: present only while is_read is false.
                      Container(
                        width: 8,
                        height: 8,
                        borderRadius: 4,
                        color: Colors.secondary,
                        visible: Not(ItemRef()['is_read']),
                      ),
                      Column(
                        crossAxis: CrossAxis.start,
                        spacing: 3,
                        children: [
                          Text(
                            ItemRef()['title'],
                            style: Styles.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            ItemRef()['message'],
                            style: Styles.bodySmall,
                            color: Colors.secondaryText,
                            maxLines: 4,
                          ),
                          Text(
                            ItemRef()['created_at'],
                            style: Styles.bodySmall,
                            color: Colors.secondaryText,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    ),
  );

  app.editPage(ff.Pages.account, (page) {
    if (!ff.Pages.account.widgets.all.any(
      (w) => w.name == 'accountNotificationsTile',
    )) {
      page.ensureInsertedBefore(
        ff.Pages.account.widgets.byKey('ListTile_81kcu172').single,
        ListTile(
          title: 'Notifications',
          leadingIcon: 'notifications_none',
          name: 'accountNotificationsTile',
          onTap: [Navigate.to(notificationsPage)],
        ),
      );
    }
  });

  // ---------------------------------------------------------------------------
  // 7e. Wishlist — saved products that follow the account, not the device
  // ---------------------------------------------------------------------------
  final wishlistPage = app.ensurePage(
    'Wishlist',
    route: '/wishlist',
    description: 'Products saved for later, shared with the website.',
    state: {'saved': wishlist},
    onLoad: loadWishlist(''),
    body: Scaffold(
      appBar: AppBar(title: 'Wishlist'),
      body: Column(
        scrollable: true,
        crossAxis: CrossAxis.start,
        spacing: 12,
        padding: 16,
        children: [
          Text(
            'Nothing saved yet. Tap the heart on any shoe to keep it here.',
            name: 'wishlistEmpty',
            style: Styles.bodyMedium,
            color: Colors.secondaryText,
            visible: Equals(State(ff.Pages.wishlist.state.saved)['count'], 0),
          ),
          ListView(
            source: State(ff.Pages.wishlist.state.saved)['items'],
            shrinkWrap: true,
            scrollPhysics: ScrollPhysics.never,
            spacing: 10,
            itemBuilder:
                (item) => Container(
                  padding: 12,
                  borderRadius: 12,
                  color: Colors.secondaryBackground,
                  onTap: [
                    Navigate.to(
                      ff.Pages.shoeDetails,
                      params: {'id': ItemRef()['id']},
                    ),
                  ],
                  child: Row(
                    crossAxis: CrossAxis.center,
                    spacing: 12,
                    children: [
                      Image(
                        CustomFunction(
                          CustomFunctionHandle(
                            name: 'imgUrl',
                            args: {'image': string, 'id': int_},
                            returnType: string,
                          ),
                          args: {
                            'image': ItemRef()['image'],
                            'id': ItemRef()['id'],
                          },
                        ),
                        width: 64,
                        height: 64,
                        borderRadius: 8,
                      ),
                      Column(
                        crossAxis: CrossAxis.start,
                        spacing: 3,
                        children: [
                          Text(
                            ItemRef()['name'],
                            style: Styles.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            ItemRef()['subcategory'],
                            style: Styles.bodySmall,
                            color: Colors.secondaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            CustomFunction(
                              CustomFunctionHandle(
                                name: 'peso',
                                args: {'value': string},
                                returnType: string,
                              ),
                              args: {
                                'value': CustomFunction(
                                  CustomFunctionHandle(
                                    name: 'activePrice',
                                    args: {
                                      'price': string,
                                      'salePrice': string,
                                    },
                                    returnType: string,
                                  ),
                                  args: {
                                    'price': ItemRef()['price'],
                                    'salePrice': ItemRef()['sale_price'],
                                  },
                                ),
                              },
                            ),
                            style: Styles.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // 7f. Reviews
  // ---------------------------------------------------------------------------
  // Reading is public — the website shows reviews to anyone. Writing is gated
  // server-side to people who actually bought the shoe and haven't reviewed it
  // yet; `can_review` carries that verdict so the app only has to render it.
  final reviewsPage = app.ensurePage(
    'Reviews',
    route: '/reviews',
    description: 'Customer reviews for one shoe, and the form to add one.',
    params: {
      'productId': int_.withDefault(0),
      'shoeName': string.withDefault(''),
    },
    state: {'feed': reviewFeed},
    onLoad: loadReviews(''),
    body: Scaffold(
      appBar: AppBar(title: 'Reviews'),
      body: Column(
        scrollable: true,
        crossAxis: CrossAxis.start,
        spacing: 18,
        padding: 16,
        children: [
          Text(
            PageParam('shoeName'),
            style: Styles.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            crossAxis: CrossAxis.center,
            spacing: 8,
            children: [
              Icon('star', size: 18, color: Colors.secondary),
              Text(
                State(ff.Pages.reviews.state.feed)['average'],
                style: Styles.titleSmall,
              ),
              Text(
                State(ff.Pages.reviews.state.feed)['count'],
                style: Styles.bodySmall,
                color: Colors.secondaryText,
              ),
            ],
          ),

          // --- write a review -------------------------------------------------
          Container(
            padding: 16,
            borderRadius: 12,
            color: Colors.secondaryBackground,
            visible: State(ff.Pages.reviews.state.feed)['can_review'],
            child: Column(
              crossAxis: CrossAxis.start,
              spacing: 12,
              children: [
                Text('Write a review', style: Styles.titleSmall),
                Dropdown(
                  options: const ['5', '4', '3', '2', '1'],
                  label: 'Rating',
                  hint: 'Choose 1 to 5',
                  name: 'reviewRating',
                ),
                TextField(
                  label: 'Your review',
                  name: 'reviewComment',
                  maxLines: 4,
                ),
                Button(
                  'Post review',
                  name: 'postReview',
                  width: double.infinity,
                  height: 52,
                  borderRadius: 12,
                  onTap: [
                    ApiCall(
                      createReview,
                      outputAs: 'postReviewRes',
                      params: {
                        'token': AppState(ff.AppState.authToken),
                        'product_id': PageParam('productId'),
                        'rating': WidgetState(
                          'reviewRating',
                          WidgetStateProperty.value,
                        ),
                        'comment': WidgetState(
                          'reviewComment',
                          WidgetStateProperty.text,
                        ),
                      },
                      // The response is the whole feed again, so the list and
                      // the summary update without a second round trip.
                      onSuccess:
                          (res) => [
                            SetState(ff.Pages.reviews.state.feed, res),
                            Snackbar('Thanks — your review is up.'),
                          ],
                      onFailure: [
                        Snackbar(
                          'Could not post your review. Pick a rating and try again.',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Why the form isn't there, when it isn't.
          Text(
            'You can review this shoe once you have ordered it.',
            name: 'reviewsLocked',
            style: Styles.bodySmall,
            color: Colors.secondaryText,
            visible: Not(State(ff.Pages.reviews.state.feed)['has_purchased']),
          ),
          Text(
            'You have already reviewed this shoe.',
            name: 'reviewsDone',
            style: Styles.bodySmall,
            color: Colors.secondaryText,
            visible: State(ff.Pages.reviews.state.feed)['has_reviewed'],
          ),

          // --- the reviews ----------------------------------------------------
          Text(
            'No reviews yet. Be the first once you have ordered it.',
            name: 'reviewsEmpty',
            style: Styles.bodyMedium,
            color: Colors.secondaryText,
            visible: Equals(State(ff.Pages.reviews.state.feed)['count'], 0),
          ),
          ListView(
            source: State(ff.Pages.reviews.state.feed)['items'],
            shrinkWrap: true,
            scrollPhysics: ScrollPhysics.never,
            spacing: 12,
            itemBuilder:
                (item) => Container(
                  padding: 14,
                  borderRadius: 12,
                  color: Colors.secondaryBackground,
                  child: Column(
                    crossAxis: CrossAxis.start,
                    spacing: 4,
                    children: [
                      Row(
                        mainAxis: MainAxis.spaceBetween,
                        crossAxis: CrossAxis.center,
                        spacing: 10,
                        children: [
                          Text(ItemRef()['username'], style: Styles.bodyMedium),
                          Row(
                            crossAxis: CrossAxis.center,
                            spacing: 4,
                            children: [
                              Icon('star', size: 14, color: Colors.secondary),
                              Text(
                                ItemRef()['rating'],
                                style: Styles.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        ItemRef()['comment'],
                        style: Styles.bodySmall,
                        maxLines: 6,
                      ),
                      Text(
                        ItemRef()['created_at'],
                        style: Styles.bodySmall,
                        color: Colors.secondaryText,
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    ),
  );

  // The heart on the product page. Without it the Wishlist could only ever show
  // what was saved on the website, which is half a feature.
  app.editPageState(ff.Pages.shoeDetails, (state) {
    state.ensureField('wishlisted', bool_.withDefault(false));
    state.ensureField('reviews', reviewFeed);
    // Was '9'. A shopper who never touched the size row still got a US 9 added
    // silently — no prompt, no highlight, discovered when the parcel arrived.
    // Empty means nothing is preselected and bagBlocker refuses the tap.
    state.ensureField(
      ff.Pages.shoeDetails.state.selectedSize,
      string.withDefault(''),
    );
  });

  // ShoeDetails' existing load is restated here — editPageOnLoad replaces the
  // chain — with the wishlist check appended. It runs only when signed in;
  // /api/wishlist.php answers 401 to anyone else.
  app.editPageOnLoad(ff.Pages.shoeDetails, [
    ApiCall(
      getProduct,
      outputAs: 'detailLoad',
      params: {'id': PageParam('id')},
      onSuccess:
          (res) => [
            SetState(ff.Pages.shoeDetails.state.shoe, res),
            SetState(ff.Pages.shoeDetails.state.isLoading, false),
          ],
      onFailure: [
        SetState(ff.Pages.shoeDetails.state.isLoading, false),
        Snackbar('Product not found'),
      ],
    ),
    // Public read — no sign-in needed, so this sits outside the signedIn branch.
    ApiCall(
      getReviews,
      outputAs: 'detailReviews',
      params: {
        'token': AppState(ff.AppState.authToken),
        'product_id': PageParam('id'),
      },
      onSuccess: (res) => [SetState(ff.Pages.shoeDetails.state.reviews, res)],
    ),
    If(
      AppState(ff.AppState.signedIn),
      then: [
        ApiCall(
          wishlistHas,
          outputAs: 'wishlistCheck',
          params: {
            'token': AppState(ff.AppState.authToken),
            'product_id': PageParam('id'),
          },
          onSuccess:
              (res) => [
                SetState(
                  ff.Pages.shoeDetails.state.wishlisted,
                  res['wishlisted'],
                ),
              ],
        ),
      ],
    ),
  ]);

  // A rating strip under Buy Now that opens the reviews. Guarded, because
  // ensureInsertedAfter duplicates on a re-run.
  if (!ff.Pages.shoeDetails.widgets.all.any((w) => w.name == 'reviewsStrip')) {
    app.editPage(ff.Pages.shoeDetails, (page) {
      page.ensureInsertedAfter(
        ff.Pages.shoeDetails.widgets.byKey('Button_zce571f8').single,
        Container(
          name: 'reviewsStrip',
          padding: 14,
          borderRadius: 12,
          color: Colors.secondaryBackground,
          child: Row(
            mainAxis: MainAxis.spaceBetween,
            crossAxis: CrossAxis.center,
            spacing: 10,
            children: [
              Row(
                crossAxis: CrossAxis.center,
                spacing: 6,
                children: [
                  Icon('star', size: 16, color: Colors.secondary),
                  Text('0', name: 'reviewsAverage', style: Styles.bodyMedium),
                  Text(
                    '0',
                    name: 'reviewsCount',
                    style: Styles.bodySmall,
                    color: Colors.secondaryText,
                  ),
                ],
              ),
              Icon('chevron_right', size: 18, color: Colors.secondaryText),
            ],
          ),
        ),
      );
    });
  }

  // Bound in a second pass, by key looked up on name: a widget handed to an
  // insert is compiled before it joins the tree, so bindings and taps have to
  // wait until it is actually there. Both halves are guarded, so the first run
  // inserts and the next one wires.
  final stripNode = ff.Pages.shoeDetails.widgets.all.where(
    (w) => w.name == 'reviewsStrip',
  );
  final avgNode = ff.Pages.shoeDetails.widgets.all.where(
    (w) => w.name == 'reviewsAverage',
  );
  final countNode = ff.Pages.shoeDetails.widgets.all.where(
    (w) => w.name == 'reviewsCount',
  );
  if (stripNode.isNotEmpty && avgNode.isNotEmpty && countNode.isNotEmpty) {
    app.editPage(ff.Pages.shoeDetails, (page) {
      page.bindText(
        ff.Pages.shoeDetails.widgets.byKey(avgNode.first.key).single,
        State(ff.Pages.shoeDetails.state.reviews)['average'],
      );
      page.bindText(
        ff.Pages.shoeDetails.widgets.byKey(countNode.first.key).single,
        State(ff.Pages.shoeDetails.state.reviews)['count'],
      );
      page.ensureActions(
        ff.Pages.shoeDetails.widgets.byKey(stripNode.first.key).single,
        triggerType: FFActionTriggerType.ON_TAP,
        actions: [
          Navigate.to(
            reviewsPage,
            params: {
              'productId': PageParam('id'),
              'shoeName': State(ff.Pages.shoeDetails.state.shoe)['name'],
            },
          ),
        ],
      );
    });
  }

  app.ensureAppBarActions(
    page: ff.Pages.shoeDetails,
    actions: [
      IconButton(
        'favorite_border',
        name: 'wishlistOff',
        size: 40,
        color: Colors.primaryText,
        visible: Not(State(ff.Pages.shoeDetails.state.wishlisted)),
        onTap: _toggleHeart(toggleWishlist, 'wishlistAddRes'),
      ),
      IconButton(
        'favorite',
        name: 'wishlistOn',
        size: 40,
        color: Colors.secondary,
        visible: State(ff.Pages.shoeDetails.state.wishlisted),
        onTap: _toggleHeart(toggleWishlist, 'wishlistRemoveRes'),
      ),
    ],
  );

  app.editPage(ff.Pages.account, (page) {
    if (!ff.Pages.account.widgets.all.any(
      (w) => w.name == 'accountWishlistTile',
    )) {
      page.ensureInsertedBefore(
        ff.Pages.account.widgets.byKey('ListTile_81kcu172').single,
        ListTile(
          title: 'Wishlist',
          leadingIcon: 'favorite_border',
          name: 'accountWishlistTile',
          onTap: [Navigate.to(wishlistPage)],
        ),
      );
    }
  });

  // ---------------------------------------------------------------------------
  // 7g. Help & Info — contact support, and the pages a store listing expects
  // ---------------------------------------------------------------------------
  final infoReaderPage = app.ensurePage(
    'InfoPage',
    route: '/info',
    description: 'Reads one CMS page — About, FAQs or the privacy policy.',
    params: {'slug': string.withDefault('about')},
    state: {'page': infoPage},
    onLoad: [
      ApiCall(
        getInfoPage,
        outputAs: 'infoLoad',
        params: {'slug': PageParam('slug')},
        onSuccess: (res) => [SetState(ff.Pages.infoPage.state.page, res)],
        onFailure: [Snackbar('Could not load that page.')],
      ),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'SoleCraftPH'),
      body: Column(
        scrollable: true,
        crossAxis: CrossAxis.start,
        spacing: 14,
        padding: 16,
        children: [
          Text(
            State(ff.Pages.infoPage.state.page)['title'],
            style: Styles.titleMedium,
          ),
          Text(
            State(ff.Pages.infoPage.state.page)['content'],
            style: Styles.bodyMedium,
          ),
        ],
      ),
    ),
  );

  final helpPage = app.ensurePage(
    'Help',
    route: '/help',
    description:
        'Contact support, and links to About, FAQs and the privacy policy.',
    state: {'pages': infoMenu},
    onLoad: [
      ApiCall(
        getInfoPages,
        outputAs: 'infoPagesLoad',
        onSuccess: (res) => [SetState(ff.Pages.help.state.pages, res)],
      ),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Help'),
      body: Column(
        scrollable: true,
        crossAxis: CrossAxis.start,
        spacing: 18,
        padding: 16,
        children: [
          Text('Contact support', style: Styles.titleSmall),
          Text(
            'Signed in? Leave your name and email blank and we will use your account details.',
            style: Styles.bodySmall,
            color: Colors.secondaryText,
          ),
          TextField(label: 'Your name', name: 'hpName'),
          TextField(label: 'Email', name: 'hpEmail', keyboard: Keyboard.email),
          TextField(label: 'Subject', name: 'hpSubject'),
          TextField(label: 'Message', name: 'hpMessage', maxLines: 5),
          Button(
            'Send message',
            name: 'hpSend',
            width: double.infinity,
            height: 52,
            borderRadius: 12,
            onTap: [
              ApiCall(
                sendContact,
                outputAs: 'contactRes',
                params: {
                  'token': AppState(ff.AppState.authToken),
                  'name': WidgetState('hpName', WidgetStateProperty.text),
                  'email': WidgetState('hpEmail', WidgetStateProperty.text),
                  'subject': WidgetState('hpSubject', WidgetStateProperty.text),
                  'message': WidgetState('hpMessage', WidgetStateProperty.text),
                },
                onSuccess: (res) => [Snackbar(res['message'])],
                onFailure: [
                  Snackbar(
                    'Could not send that. Check your email and message.',
                  ),
                ],
              ),
            ],
          ),

          Text('About SoleCraftPH', style: Styles.titleSmall),
          ListView(
            source: State(ff.Pages.help.state.pages)['items'],
            shrinkWrap: true,
            scrollPhysics: ScrollPhysics.never,
            spacing: 2,
            itemBuilder:
                (item) => ListTile(
                  title: ItemRef()['title'],
                  trailingIcon: 'chevron_right',
                  onTap: [
                    Navigate.to(
                      infoReaderPage,
                      params: {'slug': ItemRef()['slug']},
                    ),
                  ],
                ),
          ),
        ],
      ),
    ),
  );

  app.editPage(ff.Pages.account, (page) {
    if (!ff.Pages.account.widgets.all.any((w) => w.name == 'accountHelpTile')) {
      page.ensureInsertedAfter(
        ff.Pages.account.widgets.byKey('ListTile_dak60bnf').single,
        ListTile(
          title: 'Help & Info',
          leadingIcon: 'help_outline',
          name: 'accountHelpTile',
          onTap: [Navigate.to(helpPage)],
        ),
      );
    }
  });

  // ---------------------------------------------------------------------------
  // 7h. Make the Notifications and Wishlist lists actually render
  // ---------------------------------------------------------------------------
  // Both pages were created before their ListViews had shrinkWrap set, and
  // app.ensurePage is create-if-missing — it will not update the body of a page
  // that already exists, so editing the declaration above did nothing. An
  // unshrunk ListView inside a non-scrolling Column gets no height at all, which
  // is why Notifications showed its unread count and then blank space.
  //
  // These are raw node edits because the typed patch surface covers neither
  // `scrollable` nor `shrinkWrap`. Both are idempotent.
  for (final fix in <({String page, String column, String list})>[
    (
      page: 'Notifications',
      column: 'Column_e8bqu00s',
      list: 'ListView_399slaet',
    ),
    (page: 'Wishlist', column: 'Column_tb8lpkjw', list: 'ListView_hmc891ud'),
  ]) {
    final pageHandle =
        fix.page == 'Notifications'
            ? ff.Pages.notifications
            : ff.Pages.wishlist;
    app.editPage(pageHandle, (page) {
      page.mutateNode(pageHandle.widgets.byKey(fix.column).single, (node) {
        node.props.column.scrollable = true;
      });
      page.mutateNode(pageHandle.widgets.byKey(fix.list).single, (node) {
        node.props.listView.shrinkWrapValue = FFBooleanValue(inputValue: true);
        node.props.listView.scrollPhysics =
            FFScrollPhysics.FF_SCROLL_PHYSICS_NEVER;
      });
    });
  }

  // ---------------------------------------------------------------------------
  // 7i. Give "Add to Bag" a visible label back
  // ---------------------------------------------------------------------------
  // It was authored with `color: 0x00000000, fontSize: 0` — a fully transparent,
  // zero-size label — so the button showed only its cart icon. Material derives
  // a button's press overlay from its foreground colour, so a transparent label
  // also meant no ripple: the one button in the app with no tap feedback at all.
  //
  // White on the near-black fill, matching the icon beside it.
  app.editPage(ff.Pages.shoeDetails, (page) {
    page.mutateNode(
      ff.Pages.shoeDetails.widgets.byKey('Button_jfnhj8yy').single,
      (node) {
        node.props.button.text.colorValue = FFColorValue(
          inputValue: FFColor(value: Int64(0xFFFFFFFF)),
        );
        node.props.button.text.fontSizeValue = FFDoubleValue(inputValue: 16);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // 7j. Hide the account-only tiles from guests
  // ---------------------------------------------------------------------------
  // Profile, Notifications and Wishlist all call bearer-only endpoints, so a
  // signed-out tap landed on a permanently empty screen. Account already shows
  // a "You are not signed in" card with Sign in / Create an account directly
  // above these, so hiding them says the same thing without three dead ends.
  //
  // My orders and My bag stay put: My orders carries its own sign-in prompt,
  // and the bag genuinely works signed out.
  app.editPage(ff.Pages.account, (page) {
    for (final key in const [
      'ListTile_ra3qqzuv', // Profile
      'ListTile_yxcqduiu', // Notifications
      'ListTile_nfw3mvu8', // Wishlist
    ]) {
      page.bindVisible(
        ff.Pages.account.widgets.byKey(key).single,
        AppState(ff.AppState.signedIn),
      );
    }
  });

  // ---------------------------------------------------------------------------
  // 8a. Payment page — PayMongo's checkout inside the app
  // ---------------------------------------------------------------------------
  // The shopper never leaves the app: PayMongo Hosted Checkout renders in a
  // WebView, exactly the page the website redirects to. When they finish,
  // PayMongo sends the WebView on to order_success.php and its own webhook
  // marks the order paid; the button below just takes them to Confirmed, which
  // re-reads the order and shows the settled status.
  final paymentPage = app.ensurePage(
    'Payment',
    route: '/payment',
    description:
        'PayMongo Hosted Checkout, rendered in-app for GCash and Card.',
    params: {'url': string.withDefault(''), 'orderId': int_.withDefault(0)},
    body: Scaffold(
      appBar: AppBar(title: 'Complete Payment'),
      body: Column(
        children: [
          Expanded(WebView(url: PageParam('url'))),
          Container(
            padding: 16,
            child: Button(
              'Done — view my order',
              width: double.infinity,
              height: 50,
              borderRadius: 12,
              onTap: Navigate.to(
                ff.Pages.confirmed,
                params: {'orderId': PageParam('orderId')},
              ),
            ),
          ),
        ],
      ),
    ),
  );

  app.editPageState(ff.Pages.checkout, (state) {
    state.ensureField('saved', listOf(addressRow));
    // The pin belonging to whichever saved address was tapped. Empty when the
    // customer typed their address by hand, or picked one with no pin.
    state.ensureField('pickedLat', string.withDefault(''));
    state.ensureField('pickedLng', string.withDefault(''));
  });
  // ---------------------------------------------------------------------------
  // 8b. Checkout — hand GCash / Card orders to PayMongo
  // ---------------------------------------------------------------------------
  // COD is unchanged: place the order, land on Confirmed. GCash and Card now get
  // a checkout_url back from api/orders.php — the same PayMongo Hosted Checkout
  // page the website redirects to — and opening it is the LAST action, so a COD
  // order (empty url) still reaches Confirmed either way.
  //
  // Nothing here polls for payment. /webhook/paymongo.php flips the order to
  // processing/paid, and Confirmed already reads that status from GetOrder.
  app.editPage(ff.Pages.checkout, (page) {
    page.ensureActions(
      ff.Pages.checkout.widgets.byKey('Button_ye04uoud').single,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [
        const ValidateForm('checkoutForm'),
        SetState(ff.Pages.checkout.state.placing, true),
        ApiCall(
          createOrderPinned,
          outputAs: 'placeOrderRes',
          params: {
            'token': AppState(ff.AppState.authToken),
            'name': WidgetState('coName', WidgetStateProperty.text),
            'email': WidgetState('coEmail', WidgetStateProperty.text),
            'phone': WidgetState('coPhone', WidgetStateProperty.text),
            'address': WidgetState('coAddress', WidgetStateProperty.text),
            'payment': State(ff.Pages.checkout.state.payMethod),
            'latitude': State('pickedLat'),
            'longitude': State('pickedLng'),
            'items': CustomFunction(
              CustomFunctionHandle(
                name: 'orderItems',
                args: {'items': listOf(ff.Structs.bagItem)},
                returnType: json,
              ),
              args: {'items': AppState(ff.AppState.bag)},
            ),
          },
          onSuccess:
              (res) => [
                SetState(ff.Pages.checkout.state.placing, false),
                UpdateAppState.set(ff.AppState.lastOrderId, res['id']),
                // The bag used to be cleared here, before PayMongo had even
                // opened. Abandon the payment and you had an unpaid order AND
                // an empty bag, so retrying meant rebuilding the whole basket
                // — which is most of why so many online orders died unpaid.
                // COD is spent on placement; an online order is spent when the
                // Payment screen confirms the money arrived.
                If(
                  Equals(res['checkout_url'], ''),
                  then: [
                    ClearAppState(ff.AppState.bag),
                    Navigate.to(
                      ff.Pages.confirmed,
                      allowBack: false,
                      params: {'orderId': res['id']},
                    ),
                  ],
                  orElse: [
                    Navigate.to(
                      paymentPage,
                      params: {
                        'url': res['checkout_url'],
                        'orderId': res['id'],
                      },
                    ),
                  ],
                ),
              ],
          onFailure: [
            SetState(ff.Pages.checkout.state.placing, false),
            Snackbar(
              'Could not place the order. Check your details and try again.',
            ),
          ],
        ),
      ],
    );
  });

  app.editPage(ff.Pages.register, (page) {
    page.ensureActions(
      ff.Pages.register.widgets.byKey('Button_epmjm449').single,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [
        SetState(ff.Pages.register.state.busy, true),
        ApiCall(
          register,
          outputAs: 'registerRes',
          params: {
            'username': WidgetState('rgUsername', WidgetStateProperty.text),
            'email': WidgetState('rgEmail', WidgetStateProperty.text),
            'password': WidgetState('rgPassword', WidgetStateProperty.text),
            'full_name': WidgetState('rgFullName', WidgetStateProperty.text),
          },
          onSuccess:
              (res) => [
                SetState(ff.Pages.register.state.busy, false),
                UpdateAppState.set(ff.AppState.authToken, res['token']),
                UpdateAppState.set(ff.AppState.signedIn, true),
                UpdateAppState.set(ff.AppState.userId, res['user']['id']),
                UpdateAppState.set(
                  ff.AppState.username,
                  res['user']['username'],
                ),
                UpdateAppState.set(ff.AppState.userEmail, res['user']['email']),
                UpdateAppState.set(
                  ff.AppState.userFullName,
                  res['user']['full_name'],
                ),
                UpdateAppState.set(ff.AppState.userRole, res['user']['role']),
                UpdateAppState.set(
                  ff.AppState.isAdmin,
                  res['user']['is_admin'],
                ),
                Snackbar('Welcome to SoleCraftPH!'),
                Navigate.to(ff.Pages.shop),
                ...mergeBag('registerMergeRes'),
              ],
          onFailure: [
            SetState(ff.Pages.register.state.busy, false),
            Snackbar(
              'Could not create the account. That username or email may be taken.',
            ),
          ],
        ),
      ],
    );
  });

  // ---------------------------------------------------------------------------
  // 13. Settings the shop owns, and screens that admit they failed
  // ---------------------------------------------------------------------------
  // Whether a value is still in a live list. Empty means the server did not
  // say, so nothing is hidden — a shop whose settings call failed shows every
  // category rather than none.
  final listStillHas = app.customFunction(
    'listStillHas',
    args: {'values': listOf(string), 'value': string},
    returns: bool_,
    code: r'''
final live = values ?? const <String>[];
if (live.isEmpty) return true;
return live.contains(value ?? '');
''',
    description: 'Whether a live server list still contains this value.',
  );

  /// A failed load used to be a snackbar and an empty list — four seconds of
  /// explanation, then a screen indistinguishable from "you have nothing".
  /// This says so until it is fixed, and retries when tapped, which is the
  /// only thing a shopper on a dropped connection wants to do. Guarded:
  /// ensureInsertedBefore is not idempotent.
  void ensureOfflineBanner({
    required ProjectPageHandle page,
    required String anchorKey,
    required String title,
    required ProjectStateFieldHandle loadFailed,
    required List<DslAction> retry,
  }) {
    const name = 'offlineBanner';
    if (!page.widgets.all.any((w) => w.name == name)) {
      app.editPage(page, (p) {
        p.ensureInsertedBefore(
          page.widgets.byKey(anchorKey).single,
          Container(
            name: name,
            padding: 16,
            borderRadius: 12,
            color: Colors.secondaryBackground,
            child: Column(
              crossAxis: CrossAxis.start,
              spacing: 6,
              children: [
                Text(title, name: 'offlineTitle', style: Styles.titleSmall),
                Text(
                  'Check your connection, then tap here to try again.',
                  name: 'offlineHint',
                  style: Styles.bodySmall,
                  color: Colors.secondaryText,
                ),
              ],
            ),
          ),
        );
      });
    }
    // Bound in a second pass: a widget handed to an insert is compiled before
    // it joins the tree, so its binding and tap have to wait until it is there.
    final node = page.widgets.all.where((w) => w.name == name);
    if (node.isNotEmpty) {
      app.editPage(page, (p) {
        p.bindVisible(
          page.widgets.byKey(node.first.key).single,
          State(loadFailed),
        );
        p.ensureActions(
          page.widgets.byKey(node.first.key).single,
          triggerType: FFActionTriggerType.ON_TAP,
          actions: retry,
        );
      });
    }
  }

  // --- Shop -------------------------------------------------------------------
  app.editPageState(ff.Pages.shop, (state) {
    state.ensureField(ff.Pages.shop.state.loadFailed, bool_.withDefault(false));
  });

  /// Shop's page load, restated because editPageOnLoad replaces the chain.
  /// Settings ride along inside the success branch — everything after an
  /// ApiCall compiles into it, and they are worthless if the store is down.
  List<DslAction> loadShop(String tag) => [
    SetState(ff.Pages.shop.state.isLoading, true),
    SetState(ff.Pages.shop.state.loadFailed, false),
    ApiCall(
      getProducts,
      outputAs: 'shopLoad$tag',
      onSuccess:
          (res) => [
            SetState(ff.Pages.shop.state.shoes, res['products']),
            SetState(ff.Pages.shop.state.isLoading, false),
            // These three nest deliberately. Everything after an ApiCall
            // compiles into that call's success branch — siblings included —
            // so the only way to order them is to nest them, cheapest and
            // most important first. Products, then the store's switches, then
            // the category tree, then this device's push token.
            ApiCall(
              getSettings,
              outputAs: 'settingsLoad$tag',
              onSuccess:
                  (settings) => [
                    UpdateAppState.set(ff.AppState.payCod, settings['cod']),
                    UpdateAppState.set(ff.AppState.payGcash, settings['gcash']),
                    UpdateAppState.set(ff.AppState.payCard, settings['card']),
                    UpdateAppState.set(
                      ff.AppState.shopCategories,
                      settings['categories'],
                    ),
                    ApiCall(
                      getTaxonomy,
                      outputAs: 'taxonomyLoad$tag',
                      onSuccess:
                          (tax) => [
                            // Written, never re-declared. app.state() on a
                            // list-of-struct field sets its isList flag after
                            // creation, so the stored shape stops matching the
                            // declaration and every later run dies on the
                            // mismatch. The field exists; leaving the
                            // declaration out is what makes reruns survivable.
                            UpdateAppState.set('taxonomy', tax['items']),
                            If(
                              AppState(ff.AppState.signedIn),
                              then: [
                                // Android 13+ will not display a notification
                                // unless POST_NOTIFICATIONS is both declared in
                                // the manifest and granted at runtime. FlutterFlow
                                // emits the declaration from this action; the
                                // custom action below asks again through
                                // firebase_messaging, which is harmless — the
                                // system only ever shows one dialog.
                                const RequestPermissions(
                                  permission: PermissionKind.notifications,
                                ),
                                CallCustomAction(
                                  deviceToken,
                                  outputAs: 'fcmToken$tag',
                                ),
                                If(
                                  Not(Equals(ActionOutput('fcmToken$tag'), '')),
                                  then: [
                                    ApiCall(
                                      registerDevice,
                                      outputAs: 'deviceRes$tag',
                                      params: {
                                        'token': AppState(
                                          ff.AppState.authToken,
                                        ),
                                        'device_token': ActionOutput(
                                          'fcmToken$tag',
                                        ),
                                        'platform': 'android',
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                    ),
                  ],
            ),
          ],
      onFailure: [
        SetState(ff.Pages.shop.state.isLoading, false),
        SetState(ff.Pages.shop.state.loadFailed, true),
      ],
    ),
  ];

  app.editPageOnLoad(ff.Pages.shop, loadShop(''));
  ensureOfflineBanner(
    page: ff.Pages.shop,
    anchorKey: 'GridView_ilvt3kls',
    title: 'Could not reach SoleCraftPH.',
    loadFailed: ff.Pages.shop.state.loadFailed,
    retry: loadShop('Retry'),
  );

  // The three category chips are the three entries of PRODUCT_TAXONOMY, so
  // they are right until a category empties out — then the app keeps offering
  // a filter that can only come back with nothing. settings.php lists only
  // categories with something active in them.
  app.editPage(ff.Pages.shop, (page) {
    for (final chip
        in const <String, String>{
          'Container_k7rad63w': 'Athletic & Performance Footwear',
          'Container_nkjt8umr': 'Casual & Lifestyle Footwear',
          'Container_tppnzt06': 'Formal & Dress Footwear',
        }.entries) {
      page.bindVisible(
        ff.Pages.shop.widgets.byKey(chip.key).single,
        CustomFunction(
          listStillHas,
          args: {
            'values': AppState(ff.AppState.shopCategories),
            'value': chip.value,
          },
        ),
      );
    }
  });

  // --- Bag --------------------------------------------------------------------
  app.editPageState(ff.Pages.bag, (state) {
    state.ensureField(ff.Pages.bag.state.loadFailed, bool_.withDefault(false));
  });

  // Bag's own load rather than the shared pullBag: the other callers of that
  // helper sit on pages with no loadFailed field to set.
  List<DslAction> loadBag(String tag) => [
    SetState(ff.Pages.bag.state.loadFailed, false),
    SetState(ff.Pages.bag.state.isLoading, true),
    If(
      AppState(ff.AppState.signedIn),
      then: [
        ApiCall(
          cartGet,
          outputAs: 'bagLoadSyncRes$tag',
          params: {'token': AppState(ff.AppState.authToken)},
          onSuccess:
              (res) => [
                UpdateAppState.set(ff.AppState.bag, res['items']),
                SetState(ff.Pages.bag.state.isLoading, false),
              ],
          onFailure: [
            SetState(ff.Pages.bag.state.isLoading, false),
            SetState(ff.Pages.bag.state.loadFailed, true),
            ...authFailure('bagLoadSyncRes$tag', 'Could not load your bag.'),
          ],
        ),
      ],
      // A guest bag lives on the device. There is nothing to wait for, and
      // without this the spinner would never stop.
      orElse: [SetState(ff.Pages.bag.state.isLoading, false)],
    ),
  ];

  app.editPageOnLoad(ff.Pages.bag, loadBag(''));
  ensureOfflineBanner(
    page: ff.Pages.bag,
    anchorKey: 'ListView_cbzgvh4e',
    title: 'Could not load your bag.',
    loadFailed: ff.Pages.bag.state.loadFailed,
    retry: loadBag('Retry'),
  );

  // --- My Orders --------------------------------------------------------------
  app.editPageState(ff.Pages.myOrders, (state) {
    state.ensureField(
      ff.Pages.myOrders.state.loadFailed,
      bool_.withDefault(false),
    );
  });

  // The worst of the three: a failed load set isLoading false and said nothing
  // at all, so an unreachable server and an empty order history looked
  // identical.
  List<DslAction> loadMyOrders(String tag) => [
    SetState(ff.Pages.myOrders.state.isLoading, true),
    SetState(ff.Pages.myOrders.state.loadFailed, false),
    ApiCall(
      myOrdersList,
      outputAs: 'ordersLoad$tag',
      params: {'token': AppState(ff.AppState.authToken)},
      onSuccess:
          (res) => [
            SetState(ff.Pages.myOrders.state.orders, res['orders']),
            SetState(ff.Pages.myOrders.state.isLoading, false),
          ],
      onFailure: [
        SetState(ff.Pages.myOrders.state.isLoading, false),
        SetState(ff.Pages.myOrders.state.loadFailed, true),
        ...authFailure('ordersLoad$tag', 'Could not load your orders.'),
      ],
    ),
  ];

  app.editPageOnLoad(ff.Pages.myOrders, loadMyOrders(''));
  ensureOfflineBanner(
    page: ff.Pages.myOrders,
    anchorKey: 'ListView_ko415scl',
    title: 'Could not load your orders.',
    loadFailed: ff.Pages.myOrders.state.loadFailed,
    retry: loadMyOrders('Retry'),
  );

  // --- Checkout ---------------------------------------------------------------
  // Checkout offered all three methods whatever admin said, so a shopper could
  // pick one the shop had switched off and only find out when the order failed.
  app.editPage(ff.Pages.checkout, (page) {
    for (final method
        in <String, ProjectAppStateFieldHandle>{
          'Container_iuz96ohv': ff.AppState.payCod,
          'Container_ebi2q81v': ff.AppState.payGcash,
          'Container_43akn8dy': ff.AppState.payCard,
        }.entries) {
      page.bindVisible(
        ff.Pages.checkout.widgets.byKey(method.key).single,
        AppState(method.value),
      );
    }
  });

  // ---------------------------------------------------------------------------
  // 14. Pull to refresh, the two missing spinners, and the app's own name
  // ---------------------------------------------------------------------------
  // Every list in the app could only be refreshed by leaving the screen and
  // coming back, which is a strange thing to ask of someone checking whether
  // their order shipped. Each list now runs its page's own load chain on a
  // pull — the same actions, under a tag that keeps the output names apart.
  for (final list in <(ProjectPageHandle, String, List<DslAction>)>[
    (ff.Pages.shop, 'GridView_ilvt3kls', loadShop('Refresh')),
    (ff.Pages.bag, 'ListView_cbzgvh4e', loadBag('Refresh')),
    (ff.Pages.myOrders, 'ListView_ko415scl', loadMyOrders('Refresh')),
    (ff.Pages.notifications, 'ListView_399slaet', loadNotifications('Refresh')),
    (ff.Pages.wishlist, 'ListView_hmc891ud', loadWishlist('Refresh')),
    (ff.Pages.reviews, 'ListView_guswn7fv', loadReviews('Refresh')),
  ]) {
    app.editPage(list.$1, (page) {
      page.ensureActions(
        list.$1.widgets.byKey(list.$2).single,
        triggerType: FFActionTriggerType.ON_PULL_TO_REFRESH,
        actions: list.$3,
      );
    });
  }

  // Shop, MyOrders and Checkout showed a spinner while loading. ShoeDetails
  // and Bag showed nothing at all, so the wait read as "there is nothing here"
  // rather than "one moment". ShoeDetails already tracked isLoading and simply
  // never displayed it.
  app.editPageState(ff.Pages.bag, (state) {
    state.ensureField(ff.Pages.bag.state.isLoading, bool_.withDefault(false));
  });

  for (final spinner in <(ProjectPageHandle, String, DslExpression)>[
    (
      ff.Pages.shoeDetails,
      'Container_vrmuiokl',
      State(ff.Pages.shoeDetails.state.isLoading),
    ),
    (ff.Pages.bag, 'ListView_cbzgvh4e', State(ff.Pages.bag.state.isLoading)),
  ]) {
    if (!spinner.$1.widgets.all.any((w) => w.name == 'loadingSpinner')) {
      app.editPage(spinner.$1, (page) {
        page.ensureInsertedBefore(
          spinner.$1.widgets.byKey(spinner.$2).single,
          ProgressBar.circular(name: 'loadingSpinner', size: 36),
        );
      });
    }
    final node = spinner.$1.widgets.all.where(
      (w) => w.name == 'loadingSpinner',
    );
    if (node.isNotEmpty) {
      app.editPage(spinner.$1, (page) {
        page.bindVisible(
          spinner.$1.widgets.byKey(node.first.key).single,
          spinner.$3,
        );
      });
    }
  }

  // The placeholder FlutterFlow stamped on the project at creation. A Play
  // Store listing's package name can never be changed afterwards — a different
  // one is a different app, with no shared reviews, installs or update path —
  // so this is the last moment it costs nothing. The label is what sits under
  // the icon on a customer's home screen; "FINAL" is a filename habit.
  app.appNames(packageName: 'ph.solecraft.app', displayName: 'SoleCraftPH');

  // ---------------------------------------------------------------------------
  // 16. Telling a paid order from an unpaid one
  // ---------------------------------------------------------------------------
  // The Payment screen's button navigated to Confirmed and checked nothing, and
  // Confirmed said "Thank you!" whatever had happened, because OrderRow had no
  // payment_status field to read — api/orders.php has been sending one all
  // along. 22 of the 26 online orders on the test account are unpaid, which is
  // what a flow that cannot tell the difference produces.
  app.raw((project) {
    final existing = findDataStructField(
      project,
      structName: 'OrderRow',
      fieldName: 'payment_status',
    );
    if (existing == null) {
      addDataStructField(
        project,
        structName: 'OrderRow',
        fieldName: 'payment_status',
        type: FFDataTypeV2(scalarType: FFBaseDataType.String),
        description:
            'unpaid, paid or failed. Set by the PayMongo webhook, not the app.',
      );
    }
  });

  // What the confirmation screen says, which depends on both how they paid and
  // whether the money actually arrived. COD is placed-and-done; an online order
  // is only finished once the webhook has been.
  final orderHeadline = app.customFunction(
    'orderHeadline',
    args: {'method': string, 'paymentStatus': string},
    returns: string,
    code: r'''
final m = (method ?? '').toUpperCase();
final p = (paymentStatus ?? '').toLowerCase();
if (m == 'COD') return 'Order placed';
if (p == 'paid') return 'Payment received';
if (p == 'failed') return 'Payment failed';
return 'Waiting for your payment';
''',
    description: 'Headline for the confirmation screen.',
  );

  final orderSubline = app.customFunction(
    'orderSubline',
    args: {'method': string, 'paymentStatus': string},
    returns: string,
    code: r'''
final m = (method ?? '').toUpperCase();
final p = (paymentStatus ?? '').toLowerCase();
if (m == 'COD') {
  return 'Pay the rider when your shoes arrive. We will message you when the order ships.';
}
if (p == 'paid') {
  return 'Thank you! Your payment went through and your order is being prepared.';
}
if (p == 'failed') {
  return 'The payment did not go through, so this order is on hold. Your bag is still here — try again from My Orders.';
}
return 'We have not seen your payment yet. If you have just paid it can take a minute; pull down to refresh. Your bag is still here if you want to try again.';
''',
    description: 'Explanation under the confirmation headline.',
  );

  // Was 'Done — view my order', which navigated and verified nothing: tapping
  // it without paying produced a thank-you screen. It now asks the server.
  app.editPage(ff.Pages.payment, (page) {
    page.update(ff.Pages.payment.widgets.byKey('Button_fm0z5l15').single, (
      patch,
    ) {
      patch.text('I have paid — check my order');
    });
    page.ensureActions(
      ff.Pages.payment.widgets.byKey('Button_fm0z5l15').single,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [
        ApiCall(
          getOrder,
          outputAs: 'payCheck',
          params: {
            'id': PageParam('orderId'),
            'token': AppState(ff.AppState.authToken),
          },
          onSuccess:
              (res) => [
                If(
                  Equals(res['payment_status'], 'paid'),
                  then: [
                    // Only now is the bag genuinely spent.
                    ClearAppState(ff.AppState.bag),
                    Navigate.to(
                      ff.Pages.confirmed,
                      allowBack: false,
                      params: {'orderId': PageParam('orderId')},
                    ),
                  ],
                  orElse: [
                    Snackbar(
                      'We have not seen your payment yet. Finish paying above, '
                      'then tap this again.',
                    ),
                  ],
                ),
              ],
          onFailure: [
            Snackbar('Could not check your payment. Check your connection.'),
          ],
        ),
      ],
    );
  });

  // The confirmation screen, told what actually happened.
  app.editPage(ff.Pages.confirmed, (page) {
    page.bindText(
      ff.Pages.confirmed.widgets.byKey('Text_vl6tty48').single,
      CustomFunction(
        orderHeadline,
        args: {
          'method': State(ff.Pages.confirmed.state.order)['payment_method'],
          'paymentStatus':
              State(ff.Pages.confirmed.state.order)['payment_status'],
        },
      ),
    );
    page.bindText(
      ff.Pages.confirmed.widgets.byKey('Text_epdwdnvu').single,
      CustomFunction(
        orderSubline,
        args: {
          'method': State(ff.Pages.confirmed.state.order)['payment_method'],
          'paymentStatus':
              State(ff.Pages.confirmed.state.order)['payment_status'],
        },
      ),
    );
    // Continue shopping should end the checkout, not push another screen on
    // top of it. Without allowBack: false the whole flow — confirmation,
    // PayMongo's WebView, a checkout form with an empty bag — stayed on the
    // stack and the back arrow walked right into it.
    page.ensureActions(
      ff.Pages.confirmed.widgets.byKey('Button_4bxfqn66').single,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [Navigate.to(ff.Pages.shop, allowBack: false)],
    );
  });

  // ---------------------------------------------------------------------------
  // 17. Search
  // ---------------------------------------------------------------------------
  // The box raced itself. onChanged waited 2000ms before copying the text into
  // page state, and onSubmitted searched using that copy — so typing a word and
  // hitting search inside two seconds, which is everybody, searched for the
  // PREVIOUS value. On a first search that is an empty string, which is why it
  // looked like the box did nothing at all.
  //
  // Reading the field directly on submit removes the race: there is no longer a
  // copy that can be stale. The 2000ms debounce is left alone — it now only
  // updates a page-state field nothing reads, and the DSL exposes no way to
  // change a trigger's debounce, so replacing that chain risks losing it
  // entirely and firing a request per keystroke.
  app.editPage(ff.Pages.shop, (page) {
    page.ensureActions(
      ff.Pages.shop.widgets.byKey('TextField_tqobar4t').single,
      triggerType: FFActionTriggerType.ON_TEXTFIELD_SUBMIT,
      actions: [
        SetState(ff.Pages.shop.state.isLoading, true),
        ApiCall(
          getProducts,
          outputAs: 'shopSearch',
          params: {
            'q': CustomFunction(
              urlSafe,
              args: {
                'value': WidgetState(
                  'shopSearchField',
                  WidgetStateProperty.text,
                ),
              },
            ),
          },
          onSuccess:
              (res) => [
                SetState(ff.Pages.shop.state.shoes, res['products']),
                SetState(ff.Pages.shop.state.isLoading, false),
              ],
          onFailure: [
            SetState(ff.Pages.shop.state.isLoading, false),
            Snackbar('Search failed. Check your connection.'),
          ],
        ),
      ],
    );
  });

  // activeCategory holds a short key — 'all', 'performance' — that the chip
  // styling compares against, and which is no use to the API. These hold the
  // real names the server wants, so the two concerns stop fighting.
  app.editPageState(ff.Pages.shop, (state) {
    // Page state, not app state: an app-state field holding a list of structs
    // needs an isList flag set after creation, so its stored shape no longer
    // matches its declaration and the next run dies on the mismatch. Page
    // state fields go through an update path that is happy to be re-run.
    state.ensureField('activeCategoryName', string.withDefault(''));
    state.ensureField('activeSubcategory', string.withDefault(''));
  });

  /// One catalogue load, filtered by whatever category and subcategory are
  /// currently chosen. Empty strings mean "no filter", which is how
  /// product_list() already reads a missing parameter.
  List<DslAction> loadCatalog(String tag) => [
    SetState(ff.Pages.shop.state.isLoading, true),
    ApiCall(
      getProductsFiltered,
      outputAs: 'catalog$tag',
      params: {
        'category': CustomFunction(
          urlSafe,
          args: {'value': State('activeCategoryName')},
        ),
        'subcategory': CustomFunction(
          urlSafe,
          args: {'value': State('activeSubcategory')},
        ),
      },
      onSuccess:
          (res) => [
            SetState(ff.Pages.shop.state.shoes, res['products']),
            SetState(ff.Pages.shop.state.isLoading, false),
          ],
      onFailure: [
        SetState(ff.Pages.shop.state.isLoading, false),
        Snackbar('Could not load that category.'),
      ],
    ),
  ];

  // Each category chip restated: it kept its own highlight key, gained the real
  // category name, and clears any subcategory left over from the last one —
  // otherwise picking Formal while Road Running was selected asks the server
  // for dress boots that are also road running shoes, and gets nothing.
  app.editPage(ff.Pages.shop, (page) {
    for (final chip
        in const <String, List<String>>{
          'Container_xfqqjoas': ['all', ''],
          'Container_k7rad63w': [
            'performance',
            'Athletic & Performance Footwear',
          ],
          'Container_nkjt8umr': ['casual', 'Casual & Lifestyle Footwear'],
          'Container_tppnzt06': ['formal', 'Formal & Dress Footwear'],
        }.entries) {
      page.ensureActions(
        ff.Pages.shop.widgets.byKey(chip.key).single,
        triggerType: FFActionTriggerType.ON_TAP,
        actions: [
          SetState(ff.Pages.shop.state.activeCategory, chip.value[0]),
          SetState('activeCategoryName', chip.value[1]),
          SetState('activeSubcategory', ''),
          ...loadCatalog(chip.value[0]),
        ],
      );
    }
  });

  // The second row. Its source is empty until a category is picked, which is
  // what keeps it out of the way on the default view.
  // The subcategory row, built from the same CatChip component the category
  // chips use. Reusing the component rather than restyling a Container is what
  // makes the two rows match — a hand-rolled copy would drift the first time
  // either is touched, and the selected state is the whole point of the row.
  final subcategoryRow = Container(
    name: 'subcategoryRow',
    height: 44,
    padding: 4,
    child: ListView(
      name: 'subcategoryList',
      horizontal: true,
      shrinkWrap: true,
      spacing: 8,
      source: CustomFunction(
        subcategoriesOf,
        args: {
          'rows': AppState('taxonomy'),
          'category': State('activeCategoryName'),
        },
      ),
      // The Container carries the tap and the name the wiring pass looks for;
      // the component carries the look.
      itemBuilder:
          (item) => Container(
            name: 'subcategoryChip',
            child: ff.Components.catChip(
              active: Equals(State('activeSubcategory'), item),
              label: item,
            ),
          ),
    ),
  );

  if (!ff.Pages.shop.widgets.all.any((w) => w.name == 'subcategoryRow')) {
    app.editPage(ff.Pages.shop, (page) {
      page.ensureInsertedBefore(
        ff.Pages.shop.widgets.byKey('GridView_ilvt3kls').single,
        subcategoryRow,
      );
    });
  } else {
    // Already there from an earlier run, holding the plain unstyled chip.
    // ensureReplaced keeps the key, so nothing else pointing at this row
    // breaks.
    app.editPage(ff.Pages.shop, (page) {
      page.ensureReplaced(
        ff.Pages.shop.widgets
            .byKey(
              ff.Pages.shop.widgets.all
                  .firstWhere((w) => w.name == 'subcategoryRow')
                  .key,
            )
            .single,
        subcategoryRow,
      );
    });
  }

  // Bound on the pass after the insert: a widget handed to an insert is
  // compiled before it joins the tree.
  final subChip = ff.Pages.shop.widgets.all.where(
    (w) => w.name == 'subcategoryChip',
  );
  if (subChip.isNotEmpty) {
    app.editPage(ff.Pages.shop, (page) {
      page.ensureActions(
        ff.Pages.shop.widgets.byKey(subChip.first.key).single,
        triggerType: FFActionTriggerType.ON_TAP,
        actions: [
          SetState('activeSubcategory', ItemRef()),
          ...loadCatalog('Sub'),
        ],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // 19. Sign in before checking out
  // ---------------------------------------------------------------------------
  // Nothing stopped a signed-out shopper checking out. The server accepts the
  // order — user_id is nullable, same as the website — but Confirmed then reads
  // it back with an empty token and gets a 401, so a guest paid for a real
  // order and landed on a screen with no number, no amount and no status, and
  // could never find it again because My Orders needs an account.
  app.editPage(ff.Pages.bag, (page) {
    page.ensureActions(
      ff.Pages.bag.widgets.byKey('Button_vtxoiopm').single,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [
        If(
          AppState(ff.AppState.signedIn),
          then: [Navigate.to(ff.Pages.checkout)],
          orElse: [
            Snackbar('Please sign in so we can keep track of your order.'),
            // The bag survives the trip: it is app state for a guest and gets
            // merged into the account on sign-in, so nothing is lost.
            Navigate.to(ff.Pages.signIn),
          ],
        ),
      ],
    );
  });

  // ---------------------------------------------------------------------------
  // 20. Shipping details: autofill, saved addresses, and a pin
  // ---------------------------------------------------------------------------

  /// Reloads the address list. Used by the page load, by pull-to-refresh, and
  /// after each write only when that write could not return the list itself.
  List<DslAction> loadAddresses(String tag) => [
    ApiCall(
      getAddresses,
      outputAs: 'addressLoad$tag',
      params: {'token': AppState(ff.AppState.authToken)},
      onSuccess:
          (res) => [SetState(ff.Pages.addresses.state.saved, res['items'])],
      onFailure: authFailure(
        'addressLoad$tag',
        'Could not load your addresses.',
      ),
    ),
  ];

  final addressesPage = app.ensurePage(
    'Addresses',
    route: '/addresses',
    description:
        'Saved delivery addresses — Home, Work, wherever the shoes should go.',
    state: {
      'saved': listOf(addressRow),
      // The form doubles as both "add" and "edit": a non-zero editingId means
      // the save is an update. Cheaper than a second screen that would be the
      // same six fields.
      'editingId': int_.withDefault(0),
      'pin': string.withDefault(''),
      'formOpen': bool_.withDefault(false),
    },
    onLoad: loadAddresses(''),
    body: Scaffold(
      appBar: AppBar(title: 'Delivery Addresses'),
      body: Column(
        scrollable: true,
        crossAxis: CrossAxis.start,
        spacing: 14,
        padding: 16,
        children: [
          Text(
            'Saved addresses',
            name: 'addressesHeading',
            style: Styles.titleMedium,
          ),
          ListView(
            name: 'addressList',
            shrinkWrap: true,
            scrollPhysics: ScrollPhysics.never,
            spacing: 10,
            source: State(ff.Pages.addresses.state.saved),
            itemBuilder:
                (item) => Container(
                  name: 'addressCard',
                  padding: 14,
                  borderRadius: 12,
                  color: Colors.secondaryBackground,
                  borderColor: Colors.alternate,
                  borderWidth: 1,
                  child: Column(
                    crossAxis: CrossAxis.start,
                    spacing: 6,
                    children: [
                      Row(
                        mainAxis: MainAxis.spaceBetween,
                        crossAxis: CrossAxis.center,
                        children: [
                          Text(
                            item['label'],
                            name: 'addressLabel',
                            style: Styles.titleSmall,
                          ),
                          Text(
                            'Default',
                            name: 'addressDefaultTag',
                            style: Styles.bodySmall,
                            color: Colors.secondary,
                            visible: item['is_default'],
                          ),
                        ],
                      ),
                      Text(
                        item['address'],
                        name: 'addressLine',
                        style: Styles.bodySmall,
                        color: Colors.secondaryText,
                      ),
                      Text(
                        item['phone'],
                        name: 'addressPhone',
                        style: Styles.bodySmall,
                        color: Colors.secondaryText,
                      ),
                      Text(
                        'Pinned on the map',
                        name: 'addressPinned',
                        style: Styles.bodySmall,
                        color: Colors.secondary,
                        visible: Not(Equals(item['latitude'], '')),
                      ),
                      Row(
                        spacing: 10,
                        children: [
                          Container(
                            name: 'makeDefault',
                            padding: 6,
                            child: Text(
                              'Make default',
                              style: Styles.bodySmall,
                              color: Colors.primary,
                            ),
                            onTap: [
                              ApiCall(
                                defaultAddress,
                                outputAs: 'setDefaultRes',
                                params: {
                                  'token': AppState(ff.AppState.authToken),
                                  'id': item['id'],
                                },
                                onSuccess:
                                    (res) => [
                                      SetState(
                                        ff.Pages.addresses.state.saved,
                                        res['items'],
                                      ),
                                    ],
                                onFailure: [
                                  Snackbar('Could not change your default.'),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            name: 'deleteAddressAction',
                            padding: 6,
                            child: Text(
                              'Delete',
                              style: Styles.bodySmall,
                              color: Colors.error,
                            ),
                            onTap: [
                              ApiCall(
                                deleteAddress,
                                outputAs: 'deleteAddressRes',
                                params: {
                                  'token': AppState(ff.AppState.authToken),
                                  'id': item['id'],
                                },
                                onSuccess:
                                    (res) => [
                                      SetState(
                                        ff.Pages.addresses.state.saved,
                                        res['items'],
                                      ),
                                      Snackbar('Address removed.'),
                                    ],
                                onFailure: [
                                  Snackbar('Could not remove that address.'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
          Text(
            'No saved addresses yet. Add one below and checkout will fill '
            'itself in next time.',
            name: 'addressesEmpty',
            style: Styles.bodySmall,
            color: Colors.secondaryText,
            visible: CustomFunction(
              hasNoAddresses,
              args: {'rows': State(ff.Pages.addresses.state.saved)},
            ),
          ),
          Divider(),
          Text(
            'Add an address',
            name: 'addFormHeading',
            style: Styles.titleMedium,
          ),
          TextField(name: 'addrLabel', hint: 'Label — Home, Work, Mum\'s'),
          TextField(name: 'addrRecipient', hint: 'Who receives it'),
          TextField(
            name: 'addrPhone',
            hint: 'Contact number',
            keyboard: Keyboard.number,
          ),
          TextField(name: 'addrLine', hint: 'House / street / barangay / city'),
          // The map replaces what used to be a blind "use my current location":
          // it took the phone's first fix on trust, showed nothing, and offered
          // no way to correct it. Indoors that fix is routinely a street or two
          // out, and nobody found out until a rider was lost.
          //
          // The pin still rides *alongside* the typed line rather than
          // replacing it. A Philippine delivery address is often something no
          // geocoder can produce — "blk 12 lot 4, corner of the sari-sari
          // store" — so the reverse-geocoded text is a starting point the
          // customer edits, and the coordinates are what the rider actually
          // navigates by.
          Button(
            'Pin on map',
            name: 'useMyLocation',
            width: double.infinity,
            height: 52,
            borderRadius: 12,
            // Outlined, not filled. Two full-width black buttons stacked on
            // top of each other gave equal weight to picking a location and to
            // saving the address; only one of those finishes the job.
            variant: ButtonVariant.outlined,
            color: Colors.secondaryBackground,
            textColor: Colors.primaryText,
            onTap: [
              // Android returns "denied" from Geolocator.requestPermission()
              // without ever showing a dialog unless ACCESS_FINE_LOCATION is
              // declared in the manifest — which is why this button failed
              // even with location switched on at the OS level. FlutterFlow
              // emits that declaration from this action.
              const RequestPermissions(permission: PermissionKind.location),
              // Only decides where the map opens. Unlike before, an empty
              // result is no longer a dead end — the sheet opens on Manila and
              // the customer drags from there.
              CallCustomAction(currentPin, outputAs: 'pinResult'),
              UpdateAppState.set(ff.AppState.pinConfirmed, false),
              ShowBottomSheet(
                pinSheet,
                params: {
                  'startPin': ActionOutput('pinResult'),
                  'onDone': const [NavigateBack()],
                },
                // Both off so the only ways out are Confirm and Cancel. The
                // map swallows vertical drags, and a sheet that also responds
                // to them fights the gesture that moves the pin.
                enableDrag: false,
                nonDismissible: true,
              ),
              // Everything below runs when the sheet closes, which is the
              // whole reason this is a sheet and not a page: ShowBottomSheet
              // is awaited, and Navigate.to has no way to return an answer.
              If(
                AppState(ff.AppState.pinConfirmed),
                then: [
                  SetState(
                    ff.Pages.addresses.state.pin,
                    AppState(ff.AppState.draftPin),
                  ),
                  // Only overwrite the typed line when the geocoder actually
                  // found something. Blanking a carefully typed address
                  // because the lookup came back empty would be worse than
                  // not offering the autofill at all.
                  If(
                    Not(Equals(AppState(ff.AppState.draftPinText), '')),
                    then: [
                      SetFormField(
                        'addrLine',
                        AppState(ff.AppState.draftPinText),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Text(
            // Shows the address the pin resolved to rather than the word
            // "pinned", so there is something to check before saving.
            AppState(ff.AppState.draftPinText),
            name: 'pinnedNotice',
            style: Styles.bodySmall,
            color: Colors.secondary,
            maxLines: 2,
            visible: Not(Equals(State(ff.Pages.addresses.state.pin), '')),
          ),
          Button(
            'Save address',
            name: 'saveAddressButton',
            width: double.infinity,
            height: 52,
            borderRadius: 12,
            onTap: [
              ApiCall(
                saveAddress,
                outputAs: 'saveAddressRes',
                params: {
                  'token': AppState(ff.AppState.authToken),
                  'id': State(ff.Pages.addresses.state.editingId),
                  'label': WidgetState('addrLabel', WidgetStateProperty.text),
                  'recipient_name': WidgetState(
                    'addrRecipient',
                    WidgetStateProperty.text,
                  ),
                  'phone': WidgetState('addrPhone', WidgetStateProperty.text),
                  'address': WidgetState('addrLine', WidgetStateProperty.text),
                  'latitude': CustomFunction(
                    pinPart,
                    args: {
                      'pin': State(ff.Pages.addresses.state.pin),
                      'index': 0,
                    },
                  ),
                  'longitude': CustomFunction(
                    pinPart,
                    args: {
                      'pin': State(ff.Pages.addresses.state.pin),
                      'index': 1,
                    },
                  ),
                },
                onSuccess:
                    (res) => [
                      SetState(ff.Pages.addresses.state.saved, res['items']),
                      SetState(ff.Pages.addresses.state.pin, ''),
                      SetState(ff.Pages.addresses.state.editingId, 0),
                      Snackbar('Address saved.'),
                    ],
                onFailure: [
                  Snackbar(
                    'Could not save that. An address line is required, and you '
                    'can keep up to ten.',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Why the bottom of every tab page was hidden
  // ---------------------------------------------------------------------------
  // The nav bar was the "floating" type, and FlutterFlow builds that one as:
  //
  //   Scaffold(
  //     extendBody: true,
  //     body: MediaQuery(
  //       data: queryData
  //           .removeViewInsets(removeBottom: true)
  //           .removeViewPadding(removeBottom: true),
  //       child: ...),
  //     bottomNavigationBar: FloatingNavbar(...))
  //
  // `extendBody: true` runs the page *under* the bar instead of above it, and
  // the two `removeBottom` calls strip the bottom inset out of MediaQuery, so
  // the page's own SafeArea has nothing left to react to. Between them the
  // page cannot see either the nav bar or the system gesture bar, which is
  // why Clear bag sat behind both with no way to scroll it clear.
  //
  // The floating style buys exactly one thing — content visible around a
  // detached pill — and this bar is not detached: margin 0, full width,
  // elevation 0, an 8px radius. So it was paying the whole cost for none of
  // the benefit. The standard Flutter bar looks the same here and is a real
  // Scaffold slot, so every tab page gets its height reserved automatically.
  //
  // Set on the proto directly: app.bottomNav(...) is declare-once and would
  // want the four tabs restated, which risks the nav order for a change that
  // is one field. Assignment, so reruns are free.
  app.raw((project) {
    project.ensureNavBar().navBarType = FFNavBar_NavBarType.FLUTTER_NAV_BAR;
  });

  // ---------------------------------------------------------------------------
  // The addresses page body above is dead code, and has been for a while
  // ---------------------------------------------------------------------------
  // `app.ensurePage` skips an existing page entirely — creation, state fields
  // and body — so every edit made to that tree since the run that first created
  // the page has been compiled, validated, and thrown away. It is not
  // harmless-looking: the push succeeds and reports no problem.
  //
  // That is what happened to the location permission last time. The manifest
  // gained ACCESS_FINE_LOCATION, because permissions are collected from
  // declared actions across the whole app, so the fix looked verified. The
  // RequestPermissions call itself never reached addresses_widget.dart, because
  // it lives in this skipped body.
  //
  // The declaration stays because it is still what a fresh project should get.
  // Anything that has to reach *this* project goes through editPage below.
  app.editPage(ff.Pages.addresses, (page) {
    final pinButton =
        ff.Pages.addresses.widgets.byKey('Button_zss3llaf').single;

    page.update(pinButton, (patch) {
      patch.text('Pin on map');
      // Outlined, so it stops competing with Save address — two full-width
      // filled buttons stacked gave equal weight to choosing a location and to
      // finishing the job.
      patch.buttonVariant(ButtonVariant.outlined);
      patch.color(Colors.secondaryBackground);
    });

    // Replaces the ON_TAP chain outright, which is what makes this rerunnable:
    // an identical chain is left alone, a changed one swaps in.
    page.ensureActions(
      pinButton,
      triggerType: FFActionTriggerType.ON_TAP,
      actions: [
        const RequestPermissions(permission: PermissionKind.location),
        CallCustomAction(currentPin, outputAs: 'pinResult'),
        UpdateAppState.set(ff.AppState.pinConfirmed, false),
        ShowBottomSheet(
          pinSheet,
          params: {
            'startPin': ActionOutput('pinResult'),
            'onDone': const [NavigateBack()],
          },
          enableDrag: false,
          nonDismissible: true,
        ),
        If(
          AppState(ff.AppState.pinConfirmed),
          then: [
            SetState(
              ff.Pages.addresses.state.pin,
              AppState(ff.AppState.draftPin),
            ),
            If(
              Not(Equals(AppState(ff.AppState.draftPinText), '')),
              then: [
                SetFormField(
                  ff.Pages.addresses.widgets.byKey('TextField_bnm5k1u4').single,
                  AppState(ff.AppState.draftPinText),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    // Was the literal words "Location pinned", which told the customer nothing
    // they could check. Now it shows the address the pin resolved to.
    page.bindText(
      ff.Pages.addresses.widgets.byKey('Text_eqfczwlu').single,
      AppState(ff.AppState.draftPinText),
    );

    // The four boxes were bare: no fill, no radius, so they read as gaps in
    // the page rather than as fields. Fill plus a 12 radius matches the cards
    // above them.
    //
    // No border: `patch.border` throws for a TextField ("Border patches are
    // not supported"), and the input decoration is the only way in from here.
    // The white-on-paper contrast carries the shape on its own.
    for (final field in const [
      'TextField_ya1qalx9', // addrLabel
      'TextField_5gketlsz', // addrRecipient
      'TextField_ga4c02y7', // addrPhone
      'TextField_bnm5k1u4', // addrLine
    ]) {
      page.update(ff.Pages.addresses.widgets.byKey(field).single, (patch) {
        patch.color(Colors.secondaryBackground);
        patch.borderRadius(12);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // Editing a saved address
  // ---------------------------------------------------------------------------
  // `editingId` has been read by the save call and reset to zero afterwards
  // since the day this page was built, and nothing ever set it to a real id —
  // so the update path it was written for was unreachable. A typo in a saved
  // address meant deleting it and typing the whole thing again.
  if (!ff.Pages.addresses.widgets.all.any((w) => w.name == 'editAddress')) {
    app.editPage(ff.Pages.addresses, (page) {
      page.ensureInsertedBefore(
        ff.Pages.addresses.widgets.byKey('Container_k6s1ay3a').single,
        Container(
          name: 'editAddress',
          padding: 8,
          child: Text('Edit', style: Styles.bodySmall, color: Colors.primary),
        ),
      );
    });
  }

  // Second pass, as always for an inserted widget.
  final editAddress = ff.Pages.addresses.widgets.all.where(
    (w) => w.name == 'editAddress',
  );
  if (editAddress.isNotEmpty) {
    app.editPage(ff.Pages.addresses, (page) {
      page.ensureActions(
        ff.Pages.addresses.widgets.byKey(editAddress.first.key).single,
        triggerType: FFActionTriggerType.ON_TAP,
        actions: [
          // The non-zero id is the whole point: SaveAddress treats it as an
          // update rather than an eleventh new address.
          SetState(ff.Pages.addresses.state.editingId, ItemRef()['id']),
          SetFormField(
            ff.Pages.addresses.widgets.byKey('TextField_ya1qalx9').single,
            ItemRef()['label'],
          ),
          SetFormField(
            ff.Pages.addresses.widgets.byKey('TextField_5gketlsz').single,
            ItemRef()['recipient_name'],
          ),
          SetFormField(
            ff.Pages.addresses.widgets.byKey('TextField_ga4c02y7').single,
            ItemRef()['phone'],
          ),
          SetFormField(
            ff.Pages.addresses.widgets.byKey('TextField_bnm5k1u4').single,
            ItemRef()['address'],
          ),
          // Carries the existing pin through, so re-saving an address that was
          // pinned does not quietly drop the coordinates the rider uses.
          SetState(
            ff.Pages.addresses.state.pin,
            CustomFunction(
              joinPin,
              args: {
                'lat': ItemRef()['latitude'],
                'lng': ItemRef()['longitude'],
              },
            ),
          ),
          Snackbar('Editing this address. Save when you are done.'),
        ],
      );
    });
  }

  // A way in from Account, guarded because ensureInsertedBefore duplicates on
  // a rerun — which is how the Account screen grew two Notifications tiles the
  // first time round.
  app.editPage(ff.Pages.account, (page) {
    if (!ff.Pages.account.widgets.all.any((w) => w.name == 'addressesTile')) {
      page.ensureInsertedBefore(
        ff.Pages.account.widgets.byKey('ListTile_ra3qqzuv').single,
        ListTile(
          title: 'Delivery addresses',
          leadingIcon: 'location_on_outlined',
          name: 'addressesTile',
          onTap: [Navigate.to(addressesPage)],
        ),
      );
    }
  });

  // Checkout's page load set four page-state fields — fullName, email, phone,
  // address — that the four boxes on screen never read, because those are
  // bound to controllers which start empty. So a signed-in customer retyped
  // everything they had already given us, while the state sat there correctly
  // filled in. SetFormField writes into the controllers themselves.
  //
  // The saved default address wins over the profile's single address field,
  // and falls back to it when there is nothing saved yet.
  app.editPageOnLoad(ff.Pages.checkout, [
    SetFormField(
      ff.Pages.checkout.widgets.byKey('TextField_34iw5du7').single,
      AppState(ff.AppState.userFullName),
    ),
    SetFormField(
      ff.Pages.checkout.widgets.byKey('TextField_zxgfjsxb').single,
      AppState(ff.AppState.userEmail),
    ),
    SetFormField(
      ff.Pages.checkout.widgets.byKey('TextField_9li215mu').single,
      AppState(ff.AppState.userPhone),
    ),
    SetFormField(
      ff.Pages.checkout.widgets.byKey('TextField_bng08kxc').single,
      AppState(ff.AppState.userAddress),
    ),
    ApiCall(
      getAddresses,
      outputAs: 'checkoutAddresses',
      params: {'token': AppState(ff.AppState.authToken)},
      onSuccess:
          (res) => [SetState(ff.Pages.checkout.state.saved, res['items'])],
    ),
  ]);

  // A row of saved addresses above the form. Tapping one fills the boxes,
  // which is the whole point of having saved it. Empty for a customer with
  // none, which is what keeps it out of the way.
  if (!ff.Pages.checkout.widgets.all.any((w) => w.name == 'addressPicker')) {
    app.editPage(ff.Pages.checkout, (page) {
      page.ensureInsertedBefore(
        ff.Pages.checkout.widgets.byKey('TextField_34iw5du7').single,
        Container(
          name: 'addressPicker',
          height: 52,
          child: ListView(
            name: 'addressPickerList',
            horizontal: true,
            shrinkWrap: true,
            spacing: 8,
            source: State(ff.Pages.checkout.state.saved),
            itemBuilder:
                (item) => Container(
                  name: 'addressPickerChip',
                  padding: 12,
                  borderRadius: 999,
                  color: Colors.secondaryBackground,
                  borderColor: Colors.alternate,
                  borderWidth: 1,
                  alignment: Alignment.center,
                  child: Text(item['label'], style: Styles.bodySmall),
                ),
          ),
        ),
      );
    });
  }

  // Remembers which chip is the chosen one. Zero is "none", which is also what
  // a customer who typed their address by hand should see.
  app.editPageState(ff.Pages.checkout, (state) {
    state.ensureField('pickedAddressId', int_.withDefault(0));
  });

  // The chip's selected state comes from CatChip rather than a hand-rolled
  // pair of Containers, because that component already carries the look the
  // category row uses — and a second copy of it would drift the first time
  // either was touched.
  //
  // Must run before the actions below: ensureReplaced swaps the subtree and
  // takes any triggers on it with it, so attaching the tap first would just
  // throw it away. The key survives the replace, which is why the block below
  // can still find the node.
  final pickerChipNode = ff.Pages.checkout.widgets.all.where(
    (w) => w.name == 'addressPickerChip',
  );
  // Placed with constant arguments, because a replacement widget is compiled
  // before it joins the tree and `ItemRef()` outside a ListView builder is a
  // hard error there ("Item field access \"id\" used outside a ListView
  // builder"). The row's bindings go on in the pass below, once the instance
  // is really inside the builder.
  // Matched on componentName, not type: a placed component instance is a
  // Container in the tree whose componentName names the component. Matching on
  // type left this empty, the binding pass below never ran, and the row shipped
  // with `label: ''` — a line of blank chips.
  final chipIsComponent = ff.Pages.checkout.widgets.all.any(
    (w) => w.componentName == 'CatChip',
  );
  if (pickerChipNode.isNotEmpty && !chipIsComponent) {
    app.editPage(ff.Pages.checkout, (page) {
      page.ensureReplaced(
        ff.Pages.checkout.widgets.byKey(pickerChipNode.first.key).single,
        Container(
          name: 'addressPickerChip',
          child: ff.Components.catChip(active: false, label: ''),
        ),
      );
    });
  }

  final pickerChipInstance = ff.Pages.checkout.widgets.all.where(
    (w) => w.componentName == 'CatChip',
  );
  if (pickerChipInstance.isNotEmpty) {
    app.editPage(ff.Pages.checkout, (page) {
      final instance =
          ff.Pages.checkout.widgets.byKey(pickerChipInstance.first.key).single;
      page.setComponentParam(instance, 'label', ItemRef()['label']);
      page.setComponentParam(
        instance,
        'active',
        Equals(ItemRef()['id'], State('pickedAddressId')),
      );
    });
  }

  // Bound on the pass after the insert, like every other inserted widget here.
  final pickerChip = ff.Pages.checkout.widgets.all.where(
    (w) => w.name == 'addressPickerChip',
  );
  if (pickerChip.isNotEmpty) {
    app.editPage(ff.Pages.checkout, (page) {
      page.ensureActions(
        ff.Pages.checkout.widgets.byKey(pickerChip.first.key).single,
        triggerType: FFActionTriggerType.ON_TAP,
        actions: [
          SetFormField(
            ff.Pages.checkout.widgets.byKey('TextField_34iw5du7').single,
            ItemRef()['recipient_name'],
          ),
          SetFormField(
            ff.Pages.checkout.widgets.byKey('TextField_9li215mu').single,
            ItemRef()['phone'],
          ),
          SetFormField(
            ff.Pages.checkout.widgets.byKey('TextField_bng08kxc').single,
            ItemRef()['address'],
          ),
          SetState('pickedLat', ItemRef()['latitude']),
          SetState('pickedLng', ItemRef()['longitude']),
          // What makes the chip light up. Without it the row gave no sign of
          // which address the form had just been filled from — the same gap
          // the category chips and size tiles had.
          SetState('pickedAddressId', ItemRef()['id']),
          Snackbar('Delivering to your saved address.'),
        ],
      );
    });
  }

  // The same map, on checkout.
  //
  // Worth having here as well as on the addresses page: a guest ordering to
  // somewhere they will never use again has no reason to save an address, and
  // was the one customer with no way to give a pin at all.
  if (!ff.Pages.checkout.widgets.all.any(
    (w) => w.name == 'checkoutPinButton',
  )) {
    app.editPage(ff.Pages.checkout, (page) {
      page.ensureInsertedAfter(
        ff.Pages.checkout.widgets.byKey('TextField_bng08kxc').single,
        Button(
          'Pin on map',
          name: 'checkoutPinButton',
          width: double.infinity,
          height: 44,
          borderRadius: 12,
          variant: ButtonVariant.outlined,
          color: Colors.secondaryBackground,
          textColor: Colors.primaryText,
        ),
      );
    });
  }

  // It went in above the address box first, which dropped a tall outlined
  // button between Email and Delivery address and cut the run of fields in
  // half — on screen it read as belonging to the email. It belongs under the
  // box it fills.
  //
  // Not done with ensureMovedTo. That wants a parent plus a child index rather
  // than "after this sibling" (a sibling destination throws "Unsupported slot
  // placement: TextField.after", and AppBar.actions is the SDK's only named
  // multi-child slot). Given the parent Column and an index it compiled, and
  // then the project failed validation with "Action in checkoutPinButton has
  // an output variable with the same name as that of another widget" — the
  // signature of the node existing twice, i.e. the remove half of the move not
  // taking. Deleting it and letting the insert above put a fresh one in the
  // right place is duller and actually works.
  //
  // It takes three runs of this file to settle, each gated by its own guard:
  // remove, then insert after the address box, then attach the actions. That
  // is the same shape as every other inserted widget here.
  final checkoutPinIndex = _childIndexOf(
    ff.Pages.checkout.widgets.all
        .where((w) => w.name == 'checkoutPinButton')
        .firstOrNull
        ?.path,
  );
  final addressBoxIndex = _childIndexOf(
    ff.Pages.checkout.widgets.byKey('TextField_bng08kxc').single.path,
  );
  if (checkoutPinIndex != null &&
      addressBoxIndex != null &&
      checkoutPinIndex < addressBoxIndex) {
    app.editPage(ff.Pages.checkout, (page) {
      page.ensureRemoved(
        ff.Pages.checkout.widgets
            .byKey(
              ff.Pages.checkout.widgets.all
                  .firstWhere((w) => w.name == 'checkoutPinButton')
                  .key,
            )
            .single,
      );
    });
  }

  // Second pass, same as the picker chip above: a widget handed to
  // ensureInsertedBefore is compiled before it joins the tree, so its actions
  // cannot be attached until the run after the insert.
  final checkoutPin = ff.Pages.checkout.widgets.all.where(
    (w) => w.name == 'checkoutPinButton',
  );
  if (checkoutPin.isNotEmpty) {
    app.editPage(ff.Pages.checkout, (page) {
      page.ensureActions(
        ff.Pages.checkout.widgets.byKey(checkoutPin.first.key).single,
        triggerType: FFActionTriggerType.ON_TAP,
        actions: [
          const RequestPermissions(permission: PermissionKind.location),
          CallCustomAction(currentPin, outputAs: 'mapOpenAt'),
          UpdateAppState.set(ff.AppState.pinConfirmed, false),
          ShowBottomSheet(
            pinSheet,
            params: {
              'startPin': ActionOutput('mapOpenAt'),
              'onDone': const [NavigateBack()],
            },
            enableDrag: false,
            nonDismissible: true,
          ),
          If(
            AppState(ff.AppState.pinConfirmed),
            then: [
              // pickedLat / pickedLng are what CreateOrderPinned already
              // sends, so the pin reaches orders.latitude/longitude and the
              // admin order view's map link without any server change.
              SetState(
                'pickedLat',
                CustomFunction(
                  pinPart,
                  args: {'pin': AppState(ff.AppState.draftPin), 'index': 0},
                ),
              ),
              SetState(
                'pickedLng',
                CustomFunction(
                  pinPart,
                  args: {'pin': AppState(ff.AppState.draftPin), 'index': 1},
                ),
              ),
              If(
                Not(Equals(AppState(ff.AppState.draftPinText), '')),
                then: [
                  SetFormField(
                    ff.Pages.checkout.widgets
                        .byKey('TextField_bng08kxc')
                        .single,
                    AppState(ff.AppState.draftPinText),
                  ),
                ],
              ),
              Snackbar('Location pinned for this delivery.'),
            ],
          ),
        ],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // 22. Why the search box still did nothing
  // ---------------------------------------------------------------------------
  // The submit handler was fixed earlier and was correct — it reads the field
  // and calls the API. It was simply never reached: the field is generated
  // with `maxLines: null`, which in Flutter means multiline. A multiline field
  // gets a newline key instead of a search key, and pressing it inserts a line
  // break rather than firing onFieldSubmitted. So the box swallowed every
  // Enter and the search never ran — "I can't seem to enter" is exactly right.
  //
  // One line, which is what a search box is.
  app.editPage(ff.Pages.shop, (page) {
    page.mutateNode(ff.Pages.shop.widgets.byKey('TextField_tqobar4t').single, (
      node,
    ) {
      node.props.textField.maxLinesValue = FFIntegerValue(inputValue: 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 23. Making the chosen size look chosen
  // ---------------------------------------------------------------------------
  // Each size tile already held two variants, one shown when selected and one
  // when not — but the only difference between them was the text colour, and
  // both colours were dark. Tapping a size changed the state correctly and
  // looked like nothing had happened.
  //
  // The selected variant now fills with ink and prints its number in paper,
  // which is exactly what CatChip does for the category rows above. Same idea,
  // same two colours, so the two selectors read the same way.
  app.editPage(ff.Pages.shoeDetails, (page) {
    for (final key in const <String>[
      'Container_b9zgmtae', // 7
      'Container_xbzzmorq', // 8
      'Container_8ap8umo2', // 9
      'Container_0gxv45bd', // 10
      'Container_tkfz20fj', // 11
      'Container_r2y30mp6', // 12
    ]) {
      page.update(ff.Pages.shoeDetails.widgets.byKey(key).single, (patch) {
        patch.color(Colors.primary);
        patch.borderRadius(8);
        patch.padding(8);
      });
    }
    // The numbers inside those tiles, inverted so they stay legible on ink.
    for (final key in const <String>[
      'Text_dhxw5gav', // 7
      'Text_yypf8xof', // 8
      'Text_za5fo0g2', // 9
      'Text_ayahx0zy', // 10
      'Text_q79ygwh4', // 11
      'Text_sk49pcg5', // 12
    ]) {
      page.update(ff.Pages.shoeDetails.widgets.byKey(key).single, (patch) {
        patch.color(Colors.primaryBackground);
      });
    }
  });
}

/// The trailing `children[N]` index out of a generated widget path, or null
/// when the path has none.
///
/// Used to tell whether two siblings are in the order we want without holding
/// their positions as constants — the numbers shift whenever anything is
/// inserted above them.
int? _childIndexOf(String? path) {
  if (path == null) return null;
  final match = RegExp(r'\[(\d+)\]$').firstMatch(path);
  return match == null ? null : int.tryParse(match.group(1)!);
}
