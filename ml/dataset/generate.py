import json
import random
import os

INTENTS = {
    'ORDER_ITEM': [
        'order {item}', 'get me {item}', 'buy {item}', 'i want {item}',
        'please order {item}', 'can you get {item}', "i'd like to buy {item}",
        'order {quantity} {item}', 'get {quantity} {item} from {app}',
    ],
    'SEARCH_ITEM': [
        'search for {item}', 'find {item}', 'look for {item}', 'show me {item}',
        'search {item} on {app}', 'find {item} on {app}',
    ],
    'ADD_TO_CART': [
        'add {item} to cart', 'put {item} in cart', 'add to bag',
        'add {item} to my basket', 'toss {item} in cart',
    ],
    'CHANGE_QUANTITY': [
        'change quantity to {quantity}', 'make it {quantity}',
        'i want {quantity} of those', 'set quantity {quantity}',
    ],
    'SELECT_ADDRESS': [
        'deliver to {address}', 'send to {address}', 'use {address} address',
        'ship to {address}', 'deliver to my {address}',
    ],
    'CHECKOUT': [
        'checkout', 'proceed to checkout', 'buy now', 'complete purchase',
        'go to checkout', 'finalize order',
    ],
    'TEACH': [
        'teach me to {item}', 'show me how to {item}', 'record how to {item}',
        'watch me {item}', 'learn to {item}',
    ],
    'UNKNOWN': [
        'book a cab', 'play music', 'call mom', 'open camera', 'set an alarm',
        'translate this', 'send an email', 'check weather', 'book movie tickets',
        'reserve a table', 'navigate to work', 'play a game',
    ],
    'AMBIGUOUS': [
        'order pizza', 'buy something', 'get the usual', 'order from the app',
        'add it to cart', 'get food', 'do the thing',
    ],
}

ITEMS = ['rice', 'milk', 'bread', 'eggs', 'chicken', 'tomatoes', 'onions', 'butter',
         'cheese', 'pasta', 'coffee', 'sugar', 'salt', 'oil', 'flour', 'pizza',
         'burger', 'biryani', 'noodles', 'chips', 'biscuits', 'juice', 'water']
QUANTITIES = ['1', '2', '3', '4', '5', 'two', 'three', 'half kg', '1 kg', '500g']
APPS = ['swiggy', 'blinkit', 'zepto', 'amazon', 'flipkart', 'myntra']
ADDRESSES = ['home', 'work', 'office', 'mom\'s place', 'default']

def generate_utterance(template):
    text = template
    slots = {}
    if '{item}' in text:
        item = random.choice(ITEMS)
        text = text.replace('{item}', item)
        slots['item'] = item
    if '{quantity}' in text:
        qty = random.choice(QUANTITIES)
        text = text.replace('{quantity}', qty)
        slots['quantity'] = qty
    if '{app}' in text:
        app = random.choice(APPS)
        text = text.replace('{app}', app)
        slots['app'] = app
    if '{address}' in text:
        addr = random.choice(ADDRESSES)
        text = text.replace('{address}', addr)
        slots['address'] = addr
    return text, slots

def main():
    os.makedirs('ml/dataset', exist_ok=True)
    data = []
    target_counts = {
        'ORDER_ITEM': 1500, 'SEARCH_ITEM': 1500, 'ADD_TO_CART': 1200,
        'CHANGE_QUANTITY': 1000, 'SELECT_ADDRESS': 800, 'CHECKOUT': 800,
        'TEACH': 800, 'UNKNOWN': 2000, 'AMBIGUOUS': 1000,
    }
    for intent, count in target_counts.items():
        templates = INTENTS[intent]
        for _ in range(count):
            template = random.choice(templates)
            text, slots = generate_utterance(template)
            data.append({'text': text, 'intent': intent, 'slots': slots})
    random.shuffle(data)
    split = int(len(data) * 0.8)
    dev_split = int(len(data) * 0.9)
    with open('ml/dataset/train.jsonl', 'w') as f:
        for item in data[:split]:
            f.write(json.dumps(item) + '\n')
    with open('ml/dataset/dev.jsonl', 'w') as f:
        for item in data[split:dev_split]:
            f.write(json.dumps(item) + '\n')
    with open('ml/dataset/test.jsonl', 'w') as f:
        for item in data[dev_split:]:
            f.write(json.dumps(item) + '\n')
    print(f'Generated {len(data)} samples: {split} train, {dev_split-split} dev, {len(data)-dev_split} test')

if __name__ == '__main__':
    main()
