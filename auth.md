## Авторизация и пользователи

Для авторизации - не используй cookie и сессию, 
не используй редиректы

Если пользователь просит сделать страницу авторизации или сделать профиль - лучше всего сделать
отдельный файл типа profile.tsx, в котором сделать страницу его профиль
Эту-же страницу можно использовать для авторизации

Используй методы requireRealUser, requireAccountRole

Системных ролей в аккаунте 3: Admin, Staff, User
Admin - включает в себя Staff и User
Staff - включает в себя User
User - обычный пользователь

Проверить на роль сотрудника можно через ctx.user.is('Staff')
Проверить на роль админа можно через ctx.user.is('Admin')

Если нужно сделать чтобы доступ имели только сотрудники - нужно сделать так
<example filename="./staff.tsx">
import { requireAccountRole } from '@app/auth'
app.get('/', async(ctx,req) => {
  requireAccountRole(ctx, 'Staff')
  return <body>
    Page for staff: {ctx.user.displayName}
  </body>
})
</example>

Если нужно сделать чтобы доступ имели только администраторы - нужно сделать так
<example filename="./admin.tsx">
import { requireAccountRole } from '@app/auth'

app.get('/', async(ctx,req) => {
  requireAccountRole(ctx, 'Admin')
  return <body>
    Page for admin: {ctx.user.displayName}
  </body>
})
</example>

Если нужно сделать чтобы доступ имели только авторизованные пользователи - нужно сделать так
<example filename="./profile.tsx">
import { requireRealUser } from '@app/auth'

app.get('/', async(ctx,req) => {
  requireRealUser(ctx)
  return <body>
    Page for authorized user: {ctx.user.displayName}
  </body>
})
</example>



После авторизации в переменной ctx.user доступны поля
- id
- displayName
- firstName
- lastName
- gender (male, female, other)
- birthday (string)
- confirmedPhone
- confirmedEmail 
- imageUrl
- displayName
- accountRole (Admin, Staff, User)
- type (Real, Guest)

Если ты хочешь закрыть доступ к странице для неавторизованных пользователей
просто добавь в ее хендлер (на бекенде) вызов requireRealUser

НЕ ИСПОЛЬЗУЙ ПРИДУМАННЫХ ССЫЛОК ТИПА /profile /login или /logout - 
используй только те роуты, которые есть в приложении


<example filename="./index.tsx">
import {requireRealUser, requireAccountRole} from '@app/auth'
import {adminRoute} from "./admin"
import {profileRoute} from "./profile"

// Страница, доступная всем
app.get('/', async(ctx,req) => {
  return <body>
    Page for all users
    {  ctx.user && <div>
      User: {ctx.user.displayName}
      {ctx.user.is('Admin') && <div>
        <a href={adminRoute.url()}>Admin ({ctx.user.displayName})</a>
      </div>}
      {ctx.user.is('Staff') && <div>
        <a href={adminRoute.url()}>Staff ({ctx.user.displayName})</a>
      </div>}
    </div>}
    { ! ctx.user && <div>
      <a href={profileRoute.url()}>Login</a>
    </div>}
  </body>
})
</example>

<example filename="./profile.tsx">
// Страница, требующая авторизацию
const profileRoute = app.get('/', async(ctx,req) => {
  requireRealUser(ctx)
  return <body>
    Page for authorized user {ctx.user.displayName}
    { ctx.user.confirmedPhone  && <div>
      User phone: {ctx.user.confirmedPhone}
    </div>}
    { ctx.user.confirmedEmail  && <div>
      User email: {ctx.user.confirmedEmail}
    </div>}
  </body>
})
</example>

<example filename="./admin.tsx">
// Админка
const adminRoute = app.get('/', async(ctx,req) => {
  requireAccountRole(ctx, 'Admin')
  return <body>
    Page for admin: {ctx.user.displayName}
  </body>
})
</example>

Если делаешь форму профиля - обязательно сделай там возможность редактировать имя и фамилию

Редактирование аватара пока не делай

Поля firstName и lastName ты можешь обновлять через метод updateUser
Остальные поля пользователя ты можешь обновлять через метод ctx.user?.updateExtendedInfo
phone и email обновлять нельзя, это системные поля

Важно. Методы updateUser и updateExtendedInfo - серверные. Их можно вызывать только в бекенд-коде.


<example filename="./api/profile/update.ts">
import { updateUser } from '@app/users'

async function updateUserData(ctx) {
  await updateUser(ctx, ctx.user.id, {
    firstName: 'John',
    lastName: 'Doe',
  })
  await ctx.user.updateExtendedInfo(ctx, {
    gender: 'male',
    birthday: '1985-08-20',
    imageHash: hash,
  })
}
</example>


Если нужны поля пользователя, которых нет в системе, 
например, bio или его роль внутри конкретного проекта, то создай таблицу профилей пользователей
Не размещай в этой таблице поля, которые есть в системе, такие как id, displayName, firstName, lastName, gender, birthday, confirmedPhone, confirmedEmail, imageUrl, accountRole, type

<example filename="./api/profile/save.ts">
  /**
   * Table with fields
   * userId string // ctx.user.id
   * bio
   * role
   */
  import Profiles from "../tables/profiles.table"
  
  app.post('/')
    .body(s => ({
      bio: s.string().optional(),
      role: s.string().optional(),
    }))
    .handle(async(ctx, req) => {
      if (!ctx.user) {
        throw new Error('You are not authorized')
      }
      const profile = await Profiles.createOrUpdateBy(ctx, 'userId', {
        userId: ctx.user.id,
        bio: req.body.bio,
        role: req.body.role,
      })
      return profile
    })
</example>

Как получить профиль пользователя:

<example filename="./api/profile/get.ts">
  app.get('/', async(ctx, req) => {
    requireRealUser(ctx)
    const profile = await getProfile(ctx)
    return profile
  })
</example>

И в vue и в бекенд-методах будет доступен ctx.user
Его не нужно делать stringify и отдельно передавать

### Таблицы, связанные с пользователем
Чтобы завести таблицу, связаную с пользователем - добавь в нее поле userId

<example filename="./tables/deals.table.ts">
  /**
   * Table with fields
   * userId: string // ctx.user.id
   * details Order details
   * totalCost
   * description
   */
  import Deals from "../tables/deals.table"
</example>

<example filename="./api/createDeal.ts">
  import { requireAnyUser } from '@app/auth'
  import Deals from "../tables/deals.table"

  app.post('/')
    .body(s => ({
      details: s.any(),
      totalCost: s.number(),
    }))
    .handle(async(ctx, req) => {
      // Если ты хочешь, чтобы даже неавторизованный пользователь мог создать сделку,
      // вызови requireAnyUser

      const user = await requireAnyUser(ctx)
      const deal = await Deals.create(ctx, {
        userId: ctx.user.id,
        details: req.body.details,
        totalCost: req.body.totalCost,
      })
      return deal
    })
</example>

<example filename="./api/getUserDeals.ts">
  import Deals from "../tables/deals.table"

  // Если ты только получаешь данные
  // не используй requireRealUser или requireAnyUser
  // Используй ТОЛЬКО ctx.user
  app.get('/', async(ctx, req) => {
    if ( ! ctx.user ) {
      return []
    }
    
    const deals = await Deals.findAll(ctx, {
      where:{
        userId: ctx.user.id,
      }
    })
  })
</example>

Чтобы сделать ссылку на авторизацию в произвольном месте - используй ссылку
/s/auth/signin?back={backUrlWithoutDomain}
где backUrlWithoutDomain - это адрес, на который нужно вернуться после авторизации
без домена, например /profile
Никогда не используй в back просто слеш. Если не знаешь что - используй адрес текущей страницы (но без домена!)

Для того чтобы выйти из аккаунта - нужно из клиентского кода сделать post-запрос на адрес /s/auth/sign-out 
ВАЖНО: не просто отправить на этот адрес, а сделать post-запрос


Если нужно ограничнить доступ не по роли, а по тем кто имеет доступ к воркспейсу - 
используй метод checkFilePermissions
<example filename="./protected.tsx">
import { checkFilePermissions } from "@app/auth"

app.use(checkFilePermissions()).html('/', async(ctx, req) => {
  return <body>
    Page for user with access to workspace
  </body>
})
</example>
