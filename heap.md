## Working with tables of data (Heap Tables)

Chatium has ability to store structured data inside tables. That tables called "Heap Tables"

These files stored inside \`tables\` directory. Table files MUST have the \`.table.ts\` extension (e.g. \`tables/categories.table.ts\`). Any table need to have some uniq addition in the name, like G2AS in t_categories_G2AS

For example, there are two tables (categories and items) and link between them to demonstrate all types of items:
<example fileName="tables/categories.table.ts">
import { Heap } from '@app/heap'

export const CategoriesTable = Heap.Table(
  't_categories_G2AS',
  {
    name: Heap.Optional(
      Heap.String({
        customMeta: { title: 'Category name' },
        searchable: { langs: ['ru', 'en'], embeddings: true },
      }),
    ),
    color: Heap.Optional(Heap.String({ customMeta: { title: 'Color' } })),
    icon: Heap.Optional(Heap.String({ customMeta: { title: 'Icon' } })),
  },
  { customMeta: { title: 'Demo categories', description: 'Categories' } },
)

export default CategoriesTable

export type CategoriesTableRow = typeof CategoriesTable.T
export type CategoriesTableRowJson = typeof CategoriesTable.JsonT

</example>

<example fileName="tables/items.table.ts">
import { Heap } from '@app/heap'

export const ItemTable = Heap.Table(
  't_items_B5CA',
  {
    title: Heap.Optional(
      Heap.String({
        customMeta: { title: 'Название (StringKind)', description: 'Текстовое поле' },
        searchable: { langs: ['ru', 'en'], embeddings: true },
      }),
    ),
    description: Heap.Optional(
      Heap.String({
        customMeta: {
          title: 'Описание (StringKind с поиском)',
          description: 'Длинное текстовое поле с поддержкой полнотекстового поиска',
        },
        searchable: { langs: ['ru', 'en'], embeddings: true },
      }),
    ),
    status: Heap.Optional(
      Heap.Enum(
        { enumKey1: 'draft', enumKey2: 'active', enumKey3: 'archived' },
        { customMeta: { title: 'Статус (EnumKind)', description: 'Перечисление с фиксированными значениями' } },
      ),
    ),
    priority: Heap.Optional(
      Heap.Enum(
        { enumKey1: 'low', enumKey2: 'medium', enumKey3: 'high', enumKey4: 'critical' },
        { customMeta: { title: 'Приоритет (EnumKind)' } },
      ),
    ),
    quantity: Heap.Optional(Heap.Number({ customMeta: { title: 'Количество (NumberKind)' } })),
    rating: Heap.Optional(
      Heap.Number({
        customMeta: { title: 'Рейтинг (NumberKind)', description: 'Числовое значение (целое или дробное)' },
      }),
    ),
    price: Heap.Optional(Heap.Money({ customMeta: { title: 'Цена (MoneyKind)' } })),
    budget: Heap.Optional(Heap.Money({ customMeta: { title: 'Бюджет (MoneyKind)' } })),
    deadline: Heap.Optional(Heap.DateTime({ customMeta: { title: 'Срок выполнения (DateKind)' } })),
    isPublic: Heap.Optional(Heap.Boolean({ customMeta: { title: 'Публичный (BooleanKind)' } })),
    isFeatured: Heap.Optional(Heap.Boolean({ customMeta: { title: 'В избранном (BooleanKind)' } })),
    category: Heap.Optional(
      Heap.RefLink('t_categories_G2AS', { customMeta: { title: 'Категория (RefLinkKind)' } }),
    ),
    owner: Heap.Optional(Heap.UserRefLink({ customMeta: { title: 'Владелец (UserRefLinkKind)' } })),
    tags: Heap.Optional(
      Heap.Array(
        Heap.Object(
          {
            name: Heap.Optional(Heap.String({ customMeta: { title: 'Название тега' } })),
            color: Heap.Optional(Heap.String({ customMeta: { title: 'Цвет тега' } })),
          },
          { customMeta: {} },
        ),
        { customMeta: { title: 'Теги (ArrayKind)', description: 'Массив объектов-тегов' } },
      ),
    ),
    images: Heap.Optional(
      Heap.Array(
        Heap.Object(
          {
            photoHash: Heap.Optional(Heap.String({ customMeta: { title: 'Хэш фотографии' } })),
            caption: Heap.Optional(Heap.String({ customMeta: { title: 'Подпись' } })),
            order: Heap.Optional(Heap.Number({ customMeta: { title: 'Порядковый номер' } })),
          },
          { customMeta: {} },
        ),
        {
          customMeta: {
            title: 'Изображения (ArrayKind с объектами)',
            description: 'Массив объектов с хешами фотографий',
          },
        },
      ),
    ),
    settings: Heap.Optional(
      Heap.Object(
        {
          theme: Heap.Optional(
            Heap.Enum({ enumKey1: 'light', enumKey2: 'dark', enumKey3: 'auto' }, { customMeta: { title: 'Тема' } }),
          ),
          notifications: Heap.Optional(Heap.Boolean({ customMeta: { title: 'Уведомления' } })),
          fontSize: Heap.Optional(Heap.Number({ customMeta: { title: 'Размер шрифта' } })),
        },
        { customMeta: { title: 'Настройки (ObjectKind)', description: 'Вложенный объект со свойствами' } },
      ),
    ),
    metadata: Heap.Optional(Heap.Any()),
    extraData: Heap.Optional(Heap.Any()),
  },
  {
    customMeta: {
      title: 'Демонстрация всех типов полей',
      description: 'Таблица, демонстрирующая все доступные типы полей в Chatium',
    },
  },
)

export default ItemTable

export type ItemTableRow = typeof ItemTable.T
export type ItemTableRowJson = typeof ItemTable.JsonT

</example>

Definition of json:
name - globally unique name of table.
title - user readable title of table
description - user readable description of table
fields - array of fiels. Each field has:
  name - programmatically accessible name of field (property of object)
  kind - data type of field. Can be:
    StringKind - for strings
    EnumKind - for enums. Enum values should be defined in "enum" property of field.
    NumberKind - for numbers
    MoneyKind - for money
    DateKind - for dates
    BooleanKind - for booleans
    RefLinkKind - for ref links to other tables.
      - targetTablePath: Path to referenced table
    UserRefLinkKind - for ref links to system users.
    ArrayKind - for arrays. Should have "items" property with definition of array item. Only "ObjectKind" is supported for array items, to keep schema extendable
    ObjectKind - for objects. Should have "properties" property with definitions of object properties.
    AnyKind - for any values. Similar to typescript "any" type.

You can use table ONLY on backend code.
To use table, just import it into your api file:
<example fileName="api/products.ts">
import Products from "../tables/products.table"
</example>

You can enable searchable behaviour on this table by putting this object in field meta:
<example>
"searchable": {
  "enabled": true, // true if you need to search by table using Table.searchBy() and fulltext search
  "embeddings": true // true if you need to search by table using Table.searchBy() and embeddings-based search. Requires to be searchable enabled
}
</example>

Embeddings-based search named "Semantic search" in Chatium

Enable searchable behavior for all useful data - names, descriptions, titles, and so on, depending on data stored in table.

If you need to seed table with some data - use code execution tool for this.

## CRUD operations (backend only)

Import the table (default export) into an api/route file, then use it via `ctx`:

- Create: `const row = await MyTable.create(ctx, { field: value, ... })` — returns the created row (with `.id`).
- Read all: `const rows = await MyTable.findAll(ctx, {})` — optional `{ order: [{ createdAt: 'desc' }] }`.
- Delete: `await MyTable.delete(ctx, id)`.

Every row also has system fields `id`, `createdAt`, `updatedAt`. **`createdAt` / `updatedAt` are `Date` objects, not strings** — sort them with `.getTime()` (e.g. `rows.sort((a,b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())`), never `String.localeCompare` (that throws `localeCompare is not a function` at runtime).

Value formats when creating a row:
- String / Number / Boolean: the raw value.
- Money: `new Money(amount, 'RUB')` — `import { Money } from "@app/heap"`; amount is in major units (`new Money(1800,'RUB')` renders `1 800,00 ₽`). Read back with `row.price?.format(ctx)`.
- Enum: the string key, e.g. `status: 'available'`.
- DateTime: a JS `Date`, e.g. `publishedAt: new Date()`.
- RefLink: the referenced row's **id string**, e.g. `category: someCategoryRow.id`.
- UserRefLink: a user id (omit if optional — hard to seed generically).

