Imported table object has this structure:
<typedefinition>
type FilterValue<Value> = Value | Array<Value> | WhereWithOperator<Value>
type WhereWithOperator<Value> =
  | { $lt: Value }
  | { $lte: Value }
  | { $gt: Value }
  | { $gte: Value }
type Where<T> = {
  [Key in keyof T]?: FilterValue<T[Key]>
} | {
  $and: Array<Where<T>>
} | {
  $or: Array<Where<T>>
} | {
  $not: Where<T>
}
type Order<T> = {
  [Key in keyof T]?: "asc" | "desc" // only one field allowed in this type. If you need sort by multiple coumns - you MUST use multiple Orders
}
interface HeapTable<T> {
  findAll(ctx, options: {
    where?: Where<T>;
    limit?: number; // implicitly is 1000 if not passed. Could not be more than 1000.
    offset?: number,
    order?: Array<Order<T>>
  }): Promise<Array<T>>;
  findOneBy(ctx, where: Where<T>): Promise<T | null>;
  findById(ctx, id: string): Promise<T | null>
  countBy(ctx, filter?: Where<T> | null): Promise<number>
  create(ctx, fields: Omit<Partial<T>, 'id'>): Promise<T>;
  update(ctx, fields: Partial<T> & { id: string }): Promise<T>;
  delete(ctx, id: string): Promise<T>;

  // Use this method to perform full-text and embeddings-based search
  searchBy(ctx, options: {
    where?: Where<T>;
    limit?: number; // implicitly is 1000 if not passed. Could not be more than 1000.
    query: string // full text search query. You can use websearch syntax here, supported by websearch_to_tsquery postgres function
    embeddingsQuery: string // embeddings query (will be converted to embeddings and perform cosine-similarity)
  }): Promise<T[]>;
}

</typedefinition>

Do not use table directly on clientside code (vue or react component).
Always create api-route, export it, import into clientside component

<example filename="api/products/list.ts" description="Reading and filtering data">
export const apiProductsListRoute = app.get('/', async (ctx, req) => {
  cosnt products = await ProductsTable.findAll(ctx, {
    limit: 100,
    order: [
      { createdAt: 'desc' },
      { price: 'asc' },
    ]
  })

  return products;
})
</example>

<example filename="api/products/card.ts" description="Reading and filtering data">
export const apiProductCardRoute = app.get('/')
  .query(s => ({ id: s.string() }))
  .handle(async (ctx, req) => {
    return await ProductsTable.findById(ctx, req.query.id)
  })
</example>


<example filename="api/products/create.ts" description="Create data">
export const apiProductsCreateRoute = app.post('/')
  .body(s => ({
    name: s.string(),
    price: s.number(),
  }))
  .handle(async (ctx, req) => {
    const product = await ProductsTable.create(ctx, {
      name: req.body.name,
      price: req.body.price,
      // ...
    })

    return product;
  })
</example>

<example filename="/page/ProductsList.vue" description="Using create api route on clientside code">
async function submitHandler() {
  const product = await apiProductsCreateRoute.run(ctx, {
    name: "Product Name",
    price: 100,
  });
  console.log(product);
}
</example>

<example filename="api/products/update.ts" description="Updating data">
export const apiProductsUpdateRoute = app.post('/')
  .query(s => ({ id: s.string() }))
  .body(s => ({
    name: s.string(),
    price: s.number(),
  }))
  .handle(async (ctx, req) => {
    const product = await ProductsTable.update(ctx, {
      id: req.query.id,
      // ... поля для обновления
      name: req.body.name,
      price: req.body.price,
      // ...
    })

    return product;
  })
</example>

<example filename="/page/ProductsList.vue" description="Using update api route on client side">
async function submitHandler() {
  const product = await apiProductsUpdateRoute.query({ id: store.id }).run(ctx, {
    name: "Product Name",
    price: 100,
  });
  console.log(product);
}
</example>


<example filename="api/products/delete.ts" description="Delete data">
export const apiProductsDeleteRoute = app.post('/')
  .query(s => ({ id: s.string() }))
  .handle(async (ctx, req) => {
    await ProductsTable.delete(ctx, req.query.id)

    return { success: true };
  })
</example>

<example filename="/page/ProductsList.vue" description="Using delete api route on client side">
async function deleteHandler() {
  await apiProductsDeleteRoute.query({ id: store.id }).run(ctx, {});
}
</example>

### Working with Money (MoneyKind type)

<example fileName="tables/items.table">
{
  "name": "items",
  "title": "Items",
  "description": "Table of items",
  "fields": [
    {
      "name": "price",
      "kind": "MoneyKind",
      "title": "Price"
    }
  ]
}
</example>

<example>
  import { Money } from "@app/heap"; // Special class for Moneys

  // To create money, use class constructor
  const itemPrice = new Money(
    200,
    "USD"
  )
  const itemPriceWithFractions = new Money(
    200.5, // IMPORTANT: Always store monetary values as float value
    "USD"
  )

  // instance of \`Money\` should be stored in "MoneyKind" field:
  const item = await Items.create(ctx, {
    price: new Money(200, 'RUB'),
  })

  await Items.update(ctx, {
    id: item.id,
    price: new Money(300, 'RUB'),
  })

  await Items.update(ctx, {
    id: item.id,
    price: new Money(32, 'USD'),
  })

  // You SHOULD use math on Money. Always use same currency.
  await Items.update(ctx, {
    id: item.id,
    price: item.price.add(new Money(100, 'RUB'))
  })
  await Items.update(ctx, {
    id: item.id,
    price: item.price.substract(new Money(550, 'RUB'))
  })
  await Items.update(ctx, {
    id: item.id,
    price: item.price.multiply(2)
  })
  await Items.update(ctx, {
    id: item.id,
    price: item.price.divide(3)
  })

  // If you need to display moneys, use formatting:
  let formattedValueBasic = item.price.format(ctx)

  let formattedValueExtended = item.price.format(ctx, {
    maximumFractionDigits: 0,
    minimumFractionDigits: 0,
    signDisplay: 'exceptZero', // always, auto, never, exceptZero
  })
</example>

Attention! Do not use findAll to count records in table. Result will be limited to 1000 records and will be incorrect! If you need only counts - use special query with aggregations (see below) or countBy if it is enough.

### Use explicit query builder for performing complex queries with aggregations:

Heap tables has ability to perform complex queries, moving calculations to database side.
Always use this approach if you need to get only counts or aggregated data. Do not try to count using findAll or findBy methods, because they have limit of 1000 records and are inefficient for counting.

To start making query use method \`Table.select(expressions)\`. This is a full typescript definition
for that method:

<typedefinition>
// select query builder definition
interface HeapTable<T> {
  select(columns: Record<string /* alias */, SelectExpression>): SelectBuilder
}

type SelectExpression =
  | string // name of field. For example: "id", "params"
  | Array<string> // path to field, for example: ["params", "field"]
  | { $count: Array<SelectExpression>, $distinct?: boolean } // count() function, optionally distinct
  | { $sum: Array<SelectExpression> } // sum() function
  | { $avg: Array<SelectExpression> } // avg() function
  | { $max: Array<SelectExpression> } // max() function
  | { $min: Array<SelectExpression> } // min() function
  | { $abs: Array<SelectExpression> } // abs() function
  | { $ceil: Array<SelectExpression> } // ceil() function
  | { $coalesce: Array<SelectExpression> } // coalesce() function
  | { $floor: Array<SelectExpression> } // floor() function
  | { $concat: Array<SelectExpression> } // string concatenation
  | { $dyn: string | number | boolean | Date } // explicit literal. Useful for concatenation


interface SelectBuilder {
  where(where: Where<T>): SelectBuilder
  group(Array<string /*alias from selections*/>): SelectBuilder
  run(ctx): Promise<any> // invoking query and getting result
}
</typedefinition>

Check this example to know how to get count of rows matching query:
<example>
import Products from "../tables/products.table"

// ...

const count = await Products
  .select({
    count: { $count: [ '*' ] }
  })
  .where({
    category: 'somecategoryid'
  })
  .run(ctx)

// count is Array<{count: number}>. Use count?.[0]?.count to get numeric value
</example>

Check this example to know how to perform products analytic query:
<example>
import Products from "../tables/products.table"

// ...

const productCountByCategory = await Products
  .select({
    count: { $count: [ 'id' ] },
    categoryAlias: [ 'category' ],
  })
  .group(['categoryAlias'])
  .run(ctx)

// productCountByCategory now is Array<{count: number, categoryAlias: string}>
</example>

Prefer to use complex query builder if you need to work with possible high amount of data.
For example if you need a count of rows - do not select them all, use counting with \`SelectBuilder\`

${refLinkPrompt(ctx)}

${userRefLinkPrompt(ctx)}
`
}

const refLinkPrompt = (ctx: app.Ctx) => `

### Working with RefLinkKind type

RefLinkKind fields are used to create references between tables. They store the ID of a record from another table and provide runtime methods to access the linked record.

#### Defining RefLinkKind fields in table schema

<example fileName="tables/products.table" description="Table with RefLinkKind field">
{
  "name": "products",
  "title": "Products", 
  "description": "Products table with category reference",
  "fields": [
    {
      "name": "title",
      "kind": "StringKind",
      "title": "Product title"
    },
    {
      "name": "category",
      "kind": "RefLinkKind",
      "targetTablePath": "tables/categories.table",
      "title": "Category"
    },
    {
      "name": "price",
      "kind": "MoneyKind", 
      "title": "Price"
    }
  ]
}
</example>

<example fileName="tables/categories.table" description="Referenced table">
{
  "name": "categories",
  "title": "Categories",
  "description": "Product categories table", 
  "fields": [
    {
      "name": "name",
      "kind": "StringKind",
      "title": "Category name"
    },
    {
      "name": "description", 
      "kind": "StringKind",
      "title": "Category description"
    }
  ]
}
</example>

#### Working with RefLinkKind fields

When you retrieve a record with RefLinkKind fields, these fields contain special runtime objects (not just string IDs) that provide methods to access the referenced records.

<example filename="api/products/create.ts" description="Creating records with RefLinkKind">
import ProductsTable from "../../tables/products.table";
import CategoriesTable from "../../tables/categories.table";

export const apiCreateProductRoute = app.post('/', async (ctx, req) => {
  // First create or find a category
  const category = await CategoriesTable.create(ctx, {
    name: 'Electronics',
    description: 'Electronic devices and accessories'
  });

  // Create product with reference to category
  const product = await ProductsTable.create(ctx, {
    title: 'Smartphone',
    category: category.id, // Pass the ID of referenced record
    price: new Money(599, 'USD')
  });

  // Access the referenced category using the runtime object
  const categoryRecord = await product.category.get(ctx); // Returns full category record
  const categoryTitle = await product.category.getTitle(ctx); // Returns display title
  const categoriesTable = await product.category.getTargetTableRepo(ctx); // Returns CategoriesTable instance
  const otherCategories = await categoriesTable.findAll(ctx, { limit: 10, where: {id: {$not: category.id}} });
  
  return { 
    product, 
    categoryRecord, 
    categoryTitle,
    otherCategories,
    categoryId: product.category.id // Access ID directly
  };
});
</example>

<example filename="api/products/withCategories.ts" description="Querying records with RefLinkKind optimization">
import ProductsTable from "../../tables/products.table";
import CategoriesTable from "../../tables/categories.table";

export const apiProductsWithCategoriesRoute = app.get('/', async (ctx, req) => {
  const products = await ProductsTable.findAll(ctx, { limit: 100 });
  
  // Collect all category IDs for batch loading (optimization)
  const categoryIds = [...new Set(
    products.map(p => p.category.id).filter(Boolean)
  )];
  
  // Load all categories in one query
  const categories = await CategoriesTable.findAll(ctx, {
    where: { id: categoryIds }
  });
  
  const categoriesMap = new Map(categories.map(c => [c.id, c]));
  
  // Enrich products with category data
  const productsWithCategories = products.map(product => ({
    ...product,
    categoryData: categoriesMap.get(product.category.id)
  }));
  
  return productsWithCategories;
});
</example>

#### RefLinkKind runtime class interface

When retrieving records, RefLinkKind fields provide this interface:

<typedefinition>
interface RefLinkKind<T> {
  id: string; // ID of the referenced record
  get(ctx: app.Ctx): Promise<T | null>; // async method to get full referenced record
  getTitle(ctx: app.Ctx): Promise<string | null>; // async method to get display title of referenced record
  getTargetTableRepo(ctx: app.Ctx): Promise<HeapTable<T>>; // async method to get the table repository of the referenced record
  toJSON(): string; // returns ID of referenced record
}
</typedefinition>

<example filename="api/products/details.ts" description="Using RefLinkKind methods">
export const apiProductDetailsRoute = app.get('/')
  .query(s => ({ id: s.string() }))
  .handle(async (ctx, req) => {
    const product = await ProductsTable.findById(ctx, req.query.id);
    
    if (!product) {
      throw new Error('Product not found');
    }
    
    // Different ways to work with RefLinkKind field
    const result = {
      product,
      
      // Get just the ID (synchronous)
      categoryId: product.category.id,
      
      // Get full referenced record (asynchronous)
      categoryRecord: await product.category.get(ctx),
      
      // Get display title (asynchronous) 
      categoryTitle: await product.category.getTitle(ctx)
    };
    
    return result;
  });
</example>

#### Filtering by RefLinkKind fields

You can filter records by RefLinkKind fields using the referenced record's ID:

<example filename="api/products/byCategory.ts" description="Filtering by RefLinkKind">
export const apiProductsByCategoryRoute = app.get('/')
  .query(s => ({ categoryId: s.string() }))
  .handle(async (ctx, req) => {
    const categoryId = req.query.categoryId;
    
    // Filter products by category ID
    const products = await ProductsTable.findAll(ctx, {
      where: {
        category: categoryId // Use the ID to filter. NOT USE REFLINK OBJECT!
      },
      limit: 50
    });
    
    return products;
  });
</example>

<example filename="api/products/byCategories.ts" description="Filtering by multiple RefLinkKind values">
export const apiProductsByMultipleCategoriesRoute = app.post('/')
  .body(s => ({ categoryIds: s.array(s.string()) }))
  .handle(async (ctx, req) => {
    const categoryIds = req.body.categoryIds; // array of category IDs
    
    // Filter by multiple category IDs
    const products = await ProductsTable.findAll(ctx, {
      where: {
        category: categoryIds // Pass array of IDs
      }
    });
    
    return products;
  });
</example>

#### Complex queries with RefLinkKind

<example filename="api/analytics.ts" description="Analytics with RefLinkKind aggregation">
import ProductsTable from "../tables/products.table";

export const apiProductCountByCategoryRoute = app.get('/', async (ctx, req) => {
  // Count products by category using query builder
  const stats = await ProductsTable
    .select({
      categoryId: 'category', // RefLinkKind field will be resolved to ID
      productCount: { $count: ['id'] }
    })
    .group(['categoryId'])
    .run(ctx);
  
  // stats is Array<{categoryId: string, productCount: number}>
  return stats;
});
</example>

**Important points about RefLinkKind:**
- RefLinkKind fields store string ID when saving and return runtime object when retrieving
- Always use \`.id\` to get the ID value from RefLinkKind objects
- Use batch loading (collect IDs first, then query) for performance when working with many records
- RefLinkKind fields can be filtered using string IDs or arrays of IDs
- The \`get(ctx)\` method returns the full referenced record asynchronously
- The \`getTitle(ctx)\` method returns a display-friendly title of the referenced record
- When the reflinks go to the clientside, they are serialized to just the ID string
`

const userRefLinkPrompt = (ctx: app.Ctx) =>
  `
### Working with system users (UserRefLinkKind type) and SmartUser class.

You can use fields of type UserRefLinkKind to reference system users.
This field stores id of user.

The SmartUser class is available for working with users in code. All necessary types and methods are located in the \`@app/auth\` library.

<typedefinition>
import { 
  SmartUser, 
  findUsers, 
  findUserById, 
  findUsersByIds, 
  getUserById,
  createRealUser, 
  createOrUpdateBotUser,
  findIdentities, 
  normalizeIdentityKey,
  createUnconfirmedIdentity,
  requireAnyUser,
  requireRealUser,
  requireAccountRole,
  type Identity,
  type AccountRole,
  type AuthProvider
} from '@app/auth';
</typedefinition>

#### Finding users

<example filename="api/users/list.ts" description="Finding all users with filtering">
export const apiUsersListRoute = app.get('/')
  .query(s => ({
    email: s.string().optional(),
  }))
  .handle(async (ctx, req) => {
    // Find all users with default limit 1000
    const allUsers = await findUsers(ctx, {limit: 1000});
    
    // Find with filtering
    // IMPORTANT! You can use only fields "type", "accountRole", "username", "fuzzyText" for filtering!
    // for searching by phone/email/telegramId use findIdentities + findUserById!
    const realUsers = await findUsers(ctx, {
      where: { 
        type: 'Real',
        accountRole: ['Admin', 'Staff']
      },
      limit: 50,
      offset: 0
    });
    
    // Find by name
    const usersByName = await findUsers(ctx, {
      where: { 
        fuzzyText: 'john',  // search by first/last name
        username: 'john_doe' // exact search by username
      }
    });

    // Find by identity (email, phone, telegramId, etc.)
    const identities = req.query.email
      ? await findIdentities(ctx, {
          where: {
            type: 'Email', // 'Phone' | 'TelegramId',
            key: normalizeIdentityKey('Email', req.query.email), // key normalization
            // createdAt ({$gt | $lt | $gte | $lte: Date})
            // updatedAt ({$gt | $lt | $gte | $lte: Date})
            // userId (string)
          },
          // optional limit, offset, order
        })
      : []

    const [identity] = identities

    const userByIdentity: SmartUser | null = identity ? await findUserById(ctx, identity.userId) : null;
    
    return { allUsers, realUsers, usersByName, userByIdentity };
  });
</example>

<example filename="api/users/byId.ts" description="Find user by ID">
export const apiUserByIdRoute = app.get('/')
  .query(s => ({ id: s.string() }))
  .handle(async (ctx, req) => {
    // Get user by ID (throws error if not found)
    const user = await getUserById(ctx, req.query.id);
    
    // Safe user retrieval (returns null if not found)
    const userOrNull = await findUserById(ctx, req.query.id);
    
    return { user, userOrNull };
  });
</example>

<example filename="api/users/byIds.ts" description="Get multiple users by ID">
export const apiUsersByIdsRoute = app.post('/')
  .body(s => ({ ids: s.array(s.string()) }))
  .handle(async (ctx, req) => {
    const userIds = req.body.ids; // array of IDs
    const users = await findUsersByIds(ctx, userIds);
    
    return users;
  });
</example>

#### Creating users

If we have identities (email, phone), we can create a real user. Before doing so, it makes sense to check that such identities don't already exist in the database. If they exist, you can simply find the user by these identities.
If there are no confirmed identities, but a user is required for the business task, you can create a Bot user using createOrUpdateBotUser.

<example filename="api/users/createReal.ts" description="Creating a real user">
export const apiCreateRealUserRoute = app.post('/').handle(async (ctx, req) => {
  const newUser = await createRealUser(ctx, {
    firstName: 'John',
    lastName: 'Doe', 
    middleName: 'Smith',
    gender: 'male', // 'male' | 'female' | 'other'
    birthday: '1990-01-15', // string in YYYY-MM-DD format or Date object
    imageHash: 'hash_of_uploaded_image',
    imageUrl: 'https://example.com/avatar.jpg',
    
    // Create identity along with user
    unconfirmedIdentities: {
      Email: normalizeIdentityKey('Email', 'john@example.com'), // will create unconfirmed Email identity
      Phone: normalizeIdentityKey('Phone', '+79001234567') // will create unconfirmed Phone identity
    }
  });
  
  return newUser;
});
</example>

<example filename="api/users/createBot.ts" description="Creating a bot user">
export const apiCreateBotUserRoute = app.post('/').handle(async (ctx, req) => {
  // Create or update bot user
  const botUser = await createOrUpdateBotUser(ctx, 'support_bot', {
    firstName: 'Support',
    lastName: 'Service',
    imageHash: 'bot_avatar_hash'
  });
  
  return botUser;
});
</example>

#### Updating users

<example filename="api/users/update.ts" description="Updating user data">
export const apiUpdateUserRoute = app.post('/')
  .query(s => ({ id: s.string() }))
  .handle(async (ctx, req) => {
    const user = await getUserById(ctx, req.query.id);
    
    // Update language
    await user.updateLang(ctx, 'en');
    
    // Update extended information
    await user.updateExtendedInfo(ctx, {
      firstName: 'New Name',
      lastName: 'New Surname',
      gender: 'female',
      birthday: '1995-05-20',
      imageHash: 'new_avatar_hash'
    });

    // Update username or password
    await user.updateUsername(ctx, 'username')
    await user.updatePassword(ctx, 'newpassword123')
    
    return { success: true };
  });
</example>

#### Working with UserRefLinkKind fields in tables

UserRefLinkKind fields in tables store user ID and allow creating relationships between records and system users.
When retrieving a table instance, the UserRefLinkKind field will contain a special runtime class (which has an id key) that allows getting a SmartUser object using the built-in asynchronous .get(ctx) method.

<example fileName="tables/orders.table" description="Table with user field">
{
  "name": "orders", 
  "title": "Orders",
  "description": "Orders table with user binding",
  "fields": [
    {
      "name": "title",
      "kind": "StringKind", 
      "title": "Order title"
    },
    {
      "name": "customer",
      "kind": "UserRefLinkKind",
      "title": "Customer"
    },
    {
      "name": "assignedTo", 
      "kind": "UserRefLinkKind",
      "title": "Assigned to"
    }
  ]
}
</example>

<example filename="api/orders/create.ts" description="Working with UserRefLinkKind fields">
import OrdersTable from "../../tables/orders.table";

export const apiCreateOrderRoute = app.post('/', async (ctx, req) => {
  // When creating a record, pass user ID
  const order = await OrdersTable.create(ctx, {
    title: 'New order',
    customer: ctx.user.id, // current user ID
    assignedTo: 'user_id_from_request' // another user ID
  });

  const customerUser: SmartUser | null = await order.customer.get(ctx); // get customer SmartUser
  const assignedUser: SmartUser | null = await findUsersById(ctx, order.assignedTo.id); // get assigned SmartUser another way
  
  return { order, customerUser, assignedUser };
});
</example>

<example filename="api/orders/ordersWithUsers.ts" description="Working with UserRefLinkKind fields">
export const apiOrdersWithUsersRoute = app.get('/', async (ctx, req) => {
  const orders = await OrdersTable.findAll(ctx, { limit: 100 });
  
  // Get all users in one query for optimization
  const userIds = [...new Set([
    ...orders.map(o => o.customer.id).filter(Boolean),
    ...orders.map(o => o.assignedTo.id).filter(Boolean)
  ])];
  
  const users = await findUsersByIds(ctx, userIds);
  const usersMap = new Map(users.map(u => [u.id, u]));
  
  // Enrich orders with user data
  const ordersWithUsers = orders.map(order => ({
    ...order,
    customerUser: usersMap.get(order.customer),
    assignedUser: usersMap.get(order.assignedTo)
  }));
  
  return ordersWithUsers;
});
</example>

#### Working with UserRefLinkKind class

When retrieving a record that has a UserRefLinkKind field, this field will contain a special runtime class with the following type:
<typedefinition>
interface UserRefLinkKind {
  id: string; // user ID
  get(ctx: app.Ctx): Promise<SmartUser | null>; // async method to get SmartUser object
  getTitle(ctx: app.Ctx): Promise<string | null>; // async method to get user display name
  toJSON(): string; // returns user ID
}
</typedefinition>

Important! Never use UserRefLinkKind field as a user ID string directly. It's an object! If you need the id, use the .id field.

#### Working with SmartUser class

SmartUser class provides a rich API for working with users:

<example filename="api/user-info.ts" description="Using SmartUser methods">
export const apiUserInfoRoute = app.get('/', async (ctx, req) => {
  const user = await getUserById(ctx, req.query.id);
  
  // Basic information
  const userInfo = {
    id: user.id,
    type: user.type, // 'Anonymous' | 'Real' | 'Bot'
    displayName: user.displayName, // automatically generated display name
    username: user.username,
    fullName: user.fullName, // firstName + middleName + lastName
    
    // Contact information
    confirmedPhone: user.confirmedPhone,
    confirmedEmail: user.confirmedEmail,
    hasPassword: user.hasPassword,
    
    // Additional fields
    firstName: user.firstName,
    middleName: user.middleName, 
    lastName: user.lastName,
    gender: user.gender,
    birthday: user.birthday,
    birthdayDate: user.birthdayDate, // Date object
    lang: user.lang,
    
    // Role and permissions
    accountRole: user.accountRole,
    isAdmin: user.is('Admin'),
    isStaff: user.is('Staff'),
    
    // Avatar
    hasImage: user.hasImage,
    imageUrl: user.imageUrl,
    imageThumbnailUrl: user.getImageThumbnailUrl(100), // with size
    smartIconProps: user.smartIconProps, // for icon components
    
    // Serialization
    json: user.toJSON() // JSON representation
  };
  
  return userInfo;
});
</example>

#### Working with user identities

declare function createUnconfirmedIdentity(ctx: RichUgcCtx, params: CreateIdentityParams): Promise<UgcIdentity>
interface CreateIdentityParams {
  userId: string
  type: 'Email' | 'Phone'
  key: Identity['key']
  isBlocked?: boolean
}
interface UgcIdentity {
  id: string
  userId: string
  type: 'Phone' | 'Email' | 'TelegramId'
  key: string
  isPrimary: boolean
  isBlocked: boolean
  confirmedBy: string | null
  lastConfirmedAt: Date | null
  createdAt: Date
  updatedAt: Date
}

<example filename="api/identities/list.ts" description="Managing identities">
export const apiUserIdentitiesRoute = app.get('/', async (ctx, req) => {
  // Find identities
  const identities = await findIdentities(ctx, {
    userId: 'user_id',
    type: 'Phone', // 'Phone' | 'Email' | 'TelegramId'
    key: '+79001234567'
  });
  
  return identities;
});
</example>

<example filename="api/identities/create.ts" description="Managing identities">
export const apiCreateIdentityRoute = app.post('/')
  .body(s => ({ email: s.string() }))
  .handle(async (ctx, req) => {
    // Create unconfirmed identity
    const newIdentity = await createUnconfirmedIdentity(ctx, {
      userId: 'user_id',
      type: 'Email',
      key: normalizeIdentityKey('Email', req.body.email)
    });
    
    return newIdentity;
  });
</example>

#### Helper functions

<example filename="api/auth-helpers.ts" description="Using helper functions">
export const apiAuthHelpersRoute = app.get('/', async (ctx, req) => {
  // Get or create user
  const user = await requireAnyUser(ctx); // will create anonymous if none exists
  
  // Require real user with conditions
  const realUser = requireRealUser(ctx);
  
  // Check role
  requireAccountRole(ctx, 'Staff'); // will throw error if role is less than Staff
  
  // Normalize identity key
  const normalizedPhone = normalizeIdentityKey('Phone', '+7 900 123 45 67');
  // will return '79001234567'
  
  return { user, realUser, normalizedPhone };
});
</example>

**Important points:**
- UserRefLinkKind fields accept string user ID when saving and return runtime object with methods when retrieving
- When the reflinks go to the client-side, they are serialized in the ID line.
- Always use findUsersByIds to get multiple users in one query
- For role checking use user.is(role) or requireAccountRole()
- When working with identities, consider their normalization through normalizeIdentityKey()