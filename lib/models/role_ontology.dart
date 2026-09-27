import 'ui_node.dart';

class RoleOntology {
  static const String searchField = 'SEARCH_FIELD';
  static const String searchSubmit = 'SEARCH_SUBMIT';
  static const String resultList = 'RESULT_LIST';
  static const String resultItem = 'RESULT_ITEM';
  static const String productCard = 'PRODUCT_CARD';
  static const String productDetail = 'PRODUCT_DETAIL';
  static const String primaryAction = 'PRIMARY_ACTION';
  static const String addToCart = 'ADD_TO_CART';
  static const String cart = 'CART';
  static const String checkout = 'CHECKOUT';
  static const String quantityIncrease = 'QUANTITY_INCREASE';
  static const String quantityDecrease = 'QUANTITY_DECREASE';
  static const String quantityValue = 'QUANTITY_VALUE';
  static const String quantityStepper = 'QUANTITY_STEPPER';
  static const String addressSelector = 'ADDRESS_SELECTOR';
  static const String addressOption = 'ADDRESS_OPTION';
  static const String filter = 'FILTER';
  static const String sort = 'SORT';
  static const String navigation = 'NAVIGATION';
  static const String back = 'BACK';
  static const String dismiss = 'DISMISS';
  static const String confirm = 'CONFIRM';
  static const String login = 'LOGIN';
  static const String password = 'PASSWORD';
  static const String otp = 'OTP';
  static const String payment = 'PAYMENT';
  static const String pay = 'PAY';
  static const String placeOrder = 'PLACE_ORDER';

  // New roles
  static const String menuItem = 'MENU_ITEM';
  static const String backButton = 'BACK_BUTTON';
  static const String homeButton = 'HOME_BUTTON';
  static const String tabBar = 'TAB_BAR';
  static const String navigationDrawer = 'NAVIGATION_DRAWER';

  static const String itemCard = 'ITEM_CARD';
  static const String itemTitle = 'ITEM_TITLE';
  static const String itemPrice = 'ITEM_PRICE';
  static const String itemImage = 'ITEM_IMAGE';

  static const String ratingStar = 'RATING_STAR';
  static const String reviewCount = 'REVIEW_COUNT';

  static const String sortFilter = 'SORT_FILTER';
  static const String applyButton = 'APPLY_BUTTON';
  static const String clearButton = 'CLEAR_BUTTON';

  static const String deliveryOption = 'DELIVERY_OPTION';
  static const String deliveryTime = 'DELIVERY_TIME';

  static const String couponField = 'COUPON_FIELD';
  static const String applyCoupon = 'APPLY_COUPON';

  static const String orderSummary = 'ORDER_SUMMARY';
  static const String orderTotal = 'ORDER_TOTAL';

  static const String removeItem = 'REMOVE_ITEM';
  static const String increaseQuantity = 'INCREASE_QUANTITY';
  static const String decreaseQuantity = 'DECREASE_QUANTITY';

  static const String confirmButton = 'CONFIRM_BUTTON';
  static const String cancelButton = 'CANCEL_BUTTON';

  static const String successScreen = 'SUCCESS_SCREEN';
  static const String orderPlaced = 'ORDER_PLACED';
  static const String orderId = 'ORDER_ID';

  static const String scrollView = 'SCROLL_VIEW';
  static const String listView = 'LIST_VIEW';
  static const String gridView = 'GRID_VIEW';

  // Aliases for compatibility
  static const String searchBox = searchField;
  static const String firstSearchResult = resultItem;
  static const String resultCard = productCard;
  static const String addToCartButton = addToCart;
  static const String deliveryAddress = addressSelector;
  static const String payButton = pay;
  static const String paymentScreen = payment;
  static const String otpField = otp;
  static const String passwordField = password;
  static const String loginScreen = login;
  static const String popupDismiss = dismiss;
  static const String cartIcon = cart;
  static const String checkoutButton = checkout;

  static const List<String> all = [
    searchField,
    searchSubmit,
    resultList,
    resultItem,
    productCard,
    productDetail,
    primaryAction,
    addToCart,
    cart,
    checkout,
    quantityIncrease,
    quantityDecrease,
    quantityValue,
    quantityStepper,
    addressSelector,
    addressOption,
    filter,
    sort,
    navigation,
    back,
    dismiss,
    confirm,
    login,
    password,
    otp,
    payment,
    pay,
    placeOrder,
    menuItem,
    backButton,
    homeButton,
    tabBar,
    navigationDrawer,
    itemCard,
    itemTitle,
    itemPrice,
    itemImage,
    ratingStar,
    reviewCount,
    sortFilter,
    applyButton,
    clearButton,
    deliveryOption,
    deliveryTime,
    couponField,
    applyCoupon,
    orderSummary,
    orderTotal,
    removeItem,
    increaseQuantity,
    decreaseQuantity,
    confirmButton,
    cancelButton,
    successScreen,
    orderPlaced,
    orderId,
    scrollView,
    listView,
    gridView,
  ];

  static String? inferRole(UiNode node) {
    double best = 0;
    String? bestRole;
    for (final r in all) {
      final s = matchScore(node, r);
      if (s > best) {
        best = s;
        bestRole = r;
      }
    }
    return best > 0.5 ? bestRole : null;
  }

  static double matchScore(UiNode node, String targetRole) {
    final text = node.text?.toLowerCase() ?? '';
    final desc = node.contentDescription?.toLowerCase() ?? '';
    final resId = node.resourceId?.toLowerCase() ?? '';
    final cls = node.className?.toLowerCase() ?? '';
    final inputType = node.inputType;
    double s = 0;

    switch (targetRole) {
      case searchField:
        if (cls.contains('edittext')) s += 0.4;
        if (resId.contains('search')) s += 0.4;
        if (desc.contains('search')) s += 0.3;
        if (text.contains('search')) s += 0.3;
        break;
      case searchSubmit:
        if (node.isClickable) s += 0.2;
        if (resId.contains('search')) s += 0.4;
        if (text.contains('search') || desc.contains('search')) s += 0.4;
        if (cls.contains('button') || cls.contains('imageview')) s += 0.2;
        break;
      case resultList:
      case listView:
        if (cls.contains('recyclerview') || cls.contains('listview')) s += 0.6;
        if (resId.contains('result') || resId.contains('list')) s += 0.3;
        break;
      case resultItem:
      case productCard:
      case itemCard:
        if (node.isClickable) s += 0.2;
        if (resId.contains('result') ||
            resId.contains('product') ||
            resId.contains('card') ||
            resId.contains('item'))
          s += 0.4;
        if (desc.contains('product') || desc.contains('item')) s += 0.3;
        break;
      case productDetail:
        if (resId.contains('detail') || resId.contains('product')) s += 0.4;
        if (text.contains('add to cart') || text.contains('buy')) s += 0.2;
        break;
      case primaryAction:
      case applyButton:
      case confirmButton:
        if (node.isClickable) s += 0.3;
        if (cls.contains('button')) s += 0.3;
        if (text.contains('add') ||
            text.contains('buy') ||
            text.contains('apply') ||
            text.contains('confirm'))
          s += 0.3;
        break;
      case addToCart:
        if (cls.contains('button') || node.isClickable) s += 0.3;
        if (text.contains('add to cart') || text.contains('add to bag'))
          s += 0.6;
        if (resId.contains('cart') || resId.contains('add')) s += 0.3;
        break;
      case cart:
        if (node.isClickable) s += 0.2;
        if (resId.contains('cart') || resId.contains('basket')) s += 0.5;
        if (desc.contains('cart') || desc.contains('basket')) s += 0.5;
        break;
      case checkout:
        if (cls.contains('button') || node.isClickable) s += 0.2;
        if (text.contains('checkout')) s += 0.6;
        if (resId.contains('checkout')) s += 0.4;
        break;
      case quantityIncrease:
      case increaseQuantity:
        if (node.isClickable) s += 0.2;
        if (text.contains('+') ||
            desc.contains('increase') ||
            resId.contains('increase') ||
            resId.contains('plus'))
          s += 0.5;
        break;
      case quantityDecrease:
      case decreaseQuantity:
        if (node.isClickable) s += 0.2;
        if (text.contains('-') ||
            text.contains('−') ||
            desc.contains('decrease') ||
            resId.contains('decrease') ||
            resId.contains('minus'))
          s += 0.5;
        break;
      case quantityValue:
        if (cls.contains('textview') || cls.contains('edittext')) s += 0.2;
        if (RegExp(r'^\d+$').hasMatch(text.trim())) s += 0.4;
        if (resId.contains('quantity') || resId.contains('qty')) s += 0.3;
        break;
      case quantityStepper:
        if (resId.contains('quantity') ||
            resId.contains('qty') ||
            resId.contains('stepper'))
          s += 0.4;
        if (text.contains('+') || text.contains('-')) s += 0.2;
        break;
      case addressSelector:
      case addressOption:
        if (node.isClickable) s += 0.2;
        if (resId.contains('address')) s += 0.4;
        if (text.contains('address') || desc.contains('address')) s += 0.4;
        break;
      case filter:
      case sortFilter:
        if (text.contains('filter') ||
            resId.contains('filter') ||
            desc.contains('filter'))
          s += 0.6;
        break;
      case sort:
        if (text.contains('sort') ||
            resId.contains('sort') ||
            desc.contains('sort'))
          s += 0.6;
        break;
      case navigation:
      case tabBar:
      case navigationDrawer:
        if (cls.contains('bottomnavigation') ||
            resId.contains('navigation') ||
            resId.contains('nav_') ||
            resId.contains('drawer') ||
            resId.contains('tab'))
          s += 0.5;
        break;
      case back:
      case backButton:
        if (text.contains('back') ||
            desc.contains('back') ||
            resId.contains('back') ||
            resId.contains('navigate_up'))
          s += 0.5;
        break;
      case dismiss:
      case cancelButton:
      case clearButton:
        if (node.isClickable) s += 0.2;
        if (resId.contains('close') ||
            resId.contains('dismiss') ||
            resId.contains('cancel') ||
            resId.contains('clear'))
          s += 0.5;
        if (text == 'x' ||
            text == 'close' ||
            text == 'cancel' ||
            text == 'clear' ||
            desc.contains('close'))
          s += 0.5;
        break;
      case confirm:
        if (node.isClickable) s += 0.3;
        if (text.contains('confirm') ||
            text.contains('ok') ||
            text.contains('yes'))
          s += 0.5;
        break;
      case login:
        if (text.contains('login') ||
            text.contains('sign in') ||
            resId.contains('login') ||
            desc.contains('login'))
          s += 0.6;
        break;
      case password:
        if (cls.contains('edittext')) s += 0.2;
        if (inputType == 128 ||
            inputType == 144 ||
            inputType == 224 ||
            inputType == 16)
          s += 0.8;
        if (resId.contains('password') || resId.contains('passwd')) s += 0.5;
        if (text.contains('password')) s += 0.4;
        break;
      case otp:
        if (cls.contains('edittext')) s += 0.2;
        if (resId.contains('otp') ||
            resId.contains('pin') ||
            resId.contains('verification'))
          s += 0.6;
        if (text.contains('otp') || text.contains('pin')) s += 0.4;
        break;
      case payment:
        if (text.contains('payment') ||
            resId.contains('payment') ||
            desc.contains('payment'))
          s += 0.6;
        break;
      case pay:
        if (cls.contains('button') || node.isClickable) s += 0.3;
        if (text.contains('pay') ||
            text.contains('place order') ||
            text.contains('confirm'))
          s += 0.6;
        if (resId.contains('pay') || resId.contains('order')) s += 0.4;
        break;
      case placeOrder:
        if (node.isClickable) s += 0.3;
        if (text.contains('place order')) s += 0.7;
        if (resId.contains('place_order') || resId.contains('placeorder'))
          s += 0.5;
        break;
      case menuItem:
        if (resId.contains('menu_item') || cls.contains('menu')) s += 0.5;
        break;
      case homeButton:
        if (text.contains('home') ||
            desc.contains('home') ||
            resId.contains('home'))
          s += 0.5;
        break;
      case itemTitle:
        if (resId.contains('title') || resId.contains('name')) s += 0.4;
        if (cls.contains('textview')) s += 0.2;
        break;
      case itemPrice:
        if (text.contains(RegExp(r'[\$₹€£]')) || resId.contains('price'))
          s += 0.6;
        break;
      case itemImage:
        if (cls.contains('imageview')) s += 0.5;
        if (resId.contains('image') ||
            resId.contains('img') ||
            resId.contains('pic'))
          s += 0.3;
        break;
      case ratingStar:
      case reviewCount:
        if (resId.contains('rating') ||
            resId.contains('star') ||
            resId.contains('review'))
          s += 0.6;
        break;
      case deliveryOption:
      case deliveryTime:
        if (resId.contains('delivery') ||
            text.contains('delivery') ||
            desc.contains('delivery'))
          s += 0.5;
        if (resId.contains('time') ||
            text.contains('min') ||
            text.contains('hr'))
          s += 0.2;
        break;
      case couponField:
        if (cls.contains('edittext') &&
            (resId.contains('coupon') ||
                text.contains('coupon') ||
                desc.contains('coupon')))
          s += 0.6;
        break;
      case applyCoupon:
        if (node.isClickable &&
            (text.contains('apply') || resId.contains('apply')) &&
            (resId.contains('coupon') || desc.contains('coupon')))
          s += 0.6;
        break;
      case orderSummary:
      case orderTotal:
        if (resId.contains('summary') ||
            resId.contains('total') ||
            text.contains('total'))
          s += 0.6;
        break;
      case removeItem:
        if (node.isClickable &&
            (text.contains('remove') ||
                resId.contains('remove') ||
                desc.contains('remove')))
          s += 0.6;
        break;
      case successScreen:
      case orderPlaced:
        if (text.contains('success') ||
            text.contains('placed') ||
            text.contains('thank you'))
          s += 0.6;
        break;
      case orderId:
        if (text.contains('order id') || resId.contains('order_id')) s += 0.6;
        break;
      case scrollView:
        if (cls.contains('scrollview')) s += 0.6;
        break;
      case gridView:
        if (cls.contains('gridview')) s += 0.6;
        break;
      default:
        if (resId.contains(targetRole.toLowerCase().replaceAll('_', '')))
          s += 0.4;
        if (text.contains(targetRole.toLowerCase().replaceAll('_', ' ')))
          s += 0.4;
        if (desc.contains(targetRole.toLowerCase().replaceAll('_', ' ')))
          s += 0.4;
        break;
    }
    return s > 1 ? 1 : s;
  }
}
